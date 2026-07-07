<#
.SYNOPSIS
    Personal Storage Reporting v3 - Intune Remediation DETECTION script (reporting only).

.DESCRIPTION
    Discovers which folders under the user profile actually hold data, to support
    migration planning. Every non-hidden top-level folder under %USERPROFILE% is sorted
    into ONE category bucket, and each bucket's size / file count / folder count are
    aggregated. Emits a SINGLE flat JSON object (one record per device) to STDOUT.

    Buckets:
      * Known             - managed standard folders (Desktop, Documents, Pictures).
      * Supported         - still-legitimate common folders (Downloads, Music, Videos).
      * Legacy            - deprecated / relic folders nobody should be using on a work
                            device (Favorites, Contacts, Searches, Links, 3D Objects,
                            Saved Games).
      * UnmanagedOneDrive - any 'OneDrive*' folder that is NOT in $ExcludeFolders
                            (i.e. consumer OneDrive, not the company OneDrive).
      * Other             - EVERYTHING else = folders the user created themselves. This is
                            the migration signal; the names are listed in
                            Other_FoldersFound.

    Classification is locale-proof for the standard known folders: their real on-disk
    paths are resolved at runtime via [Environment]::GetFolderPath (which reads the
    logged-on user's shell-folder config), so e.g. a localized "Favourites" display name
    is matched by its actual path, not by a hard-coded spelling.

    Hidden / system folders (AppData, Application Data, legacy junctions, ...) are skipped
    automatically because the top-level enumeration does NOT use -Force. Sizing inside a
    kept folder DOES use -Force, so hidden files within a real user folder still count.

    This script takes NO remediation action and ALWAYS exits 0. It never flags a device
    as non-compliant and never writes to disk - it is purely a reporting collector.

    Runs in USER context. Targets Windows PowerShell 5.1 (the Intune MExtension default).

.NOTES
    Author : Madhu Perera
    Output : Single-line JSON object to STDOUT (one row per device).
    OneDrive: .Length reports the logical size of online-only files without hydrating
              them, so Files On-Demand content is reported without being downloaded.
#>

#region ---------------------------- CONFIG ----------------------------------------

# Root folder to discover under. Supports environment variables.
$RootFolderPath = "$env:USERPROFILE"

# Category name-lists. Matched against the actual on-disk folder name (case-insensitive,
# supports * and ?). The standard known folders are ALSO matched by their resolved path
# (see $KnownFolderResolve) so localized names are caught even if the name here differs.
$KnownFolders     = @('Desktop', 'Documents', 'Pictures')
$SupportedFolders = @('Downloads', 'Music', 'Videos')
$LegacyFolders    = @('Favorites', 'Contacts', 'Searches', 'Links', '3D Objects', 'Saved Games')

# Wildcard pattern for consumer OneDrive folders (summed into the UnmanagedOneDrive bucket).
$OneDriveMatch = 'OneDrive*'

# Folder names / patterns to EXCLUDE entirely (counted in no bucket). Use for the company
# OneDrive for Business folder. In a managed deployment the tenant name is known.
$ExcludeFolders = @(
    'OneDrive - Contoso'
)

# Capacity threshold in GB. Drives the "Over<N>GB" column (checked against the COMBINED
# total of all buckets).
$CapacityThresholdGB = 1

# Map of .NET SpecialFolder members -> bucket, resolved to real paths at runtime so the
# standard known folders are classified by PATH (locale / display-name proof).
$KnownFolderResolve = [ordered]@{
    'Desktop'     = 'Known'
    'MyDocuments' = 'Known'
    'MyPictures'  = 'Known'
    'MyMusic'     = 'Supported'
    'MyVideos'    = 'Supported'
    'Favorites'   = 'Legacy'
}

# Bucket output order.
$BucketOrder = @('Known', 'Supported', 'Legacy', 'UnmanagedOneDrive', 'Other')

#endregion -------------------------------------------------------------------------


#region ---------------------------- FUNCTIONS -------------------------------------

function Get-FolderUsage {
    <#
        Returns total bytes and file count for a folder (recursive). Tolerant of
        access-denied items and reparse points so one bad path does not break the report.
        Uses -Force so hidden files INSIDE a kept folder are still counted.
    #>
    param([string]$Path)

    $bytes = 0
    $count = 0

    $items = Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue
    if ($items) {
        $measure = $items | Measure-Object -Property Length -Sum
        $bytes   = [int64]$measure.Sum
        $count   = [int]$measure.Count
    }

    return [pscustomobject]@{ Bytes = $bytes; Count = $count }
}

function Test-FolderExcluded {
    <# True if the folder name matches any exclude pattern (case-insensitive, * and ?). #>
    param([string]$Name, [string[]]$Patterns)

    foreach ($p in $Patterns) {
        if ($Name -like $p) { return $true }
    }
    return $false
}

function Test-NameInList {
    <# True if the folder name matches any entry in a category list (case-insensitive). #>
    param([string]$Name, [string[]]$List)

    foreach ($n in $List) {
        if ($Name -like $n) { return $true }
    }
    return $false
}

#endregion -------------------------------------------------------------------------


#region ---------------------------- COLLECTION ------------------------------------

# Expand any environment variables in the configured root path.
$resolvedRoot = [System.Environment]::ExpandEnvironmentVariables($RootFolderPath)

# Resolve the real known-folder paths (locale / display-name proof). path -> bucket.
$knownPathMap = @{}   # PowerShell hashtables are case-insensitive for string keys.
foreach ($sf in $KnownFolderResolve.Keys) {
    $p = ''
    try   { $p = [System.Environment]::GetFolderPath([System.Enum]::Parse([System.Environment+SpecialFolder], $sf)) }
    catch { $p = '' }
    if ($p) {
        $p = $p.TrimEnd('\', '/')
        if (-not $knownPathMap.ContainsKey($p)) { $knownPathMap[$p] = $KnownFolderResolve[$sf] }
    }
}

# Initialise bucket accumulators.
$buckets = [ordered]@{}
foreach ($b in $BucketOrder) {
    $buckets[$b] = [pscustomobject]@{
        Bytes = [int64]0
        Items = 0
        Names = (New-Object System.Collections.Generic.List[string])
    }
}

$totalBytes = [int64]0

# Enumerate DIRECT children only, WITHOUT -Force so hidden/system folders (AppData etc.)
# are skipped automatically.
$dirs = Get-ChildItem -LiteralPath $resolvedRoot -Directory -ErrorAction SilentlyContinue

foreach ($dir in $dirs) {

    # Skip reparse points / junctions (avoids loops and double-counting).
    if ($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }

    $name = $dir.Name
    $full = $dir.FullName.TrimEnd('\', '/')

    # --- Classify into exactly one bucket -----------------------------------------
    if (Test-FolderExcluded -Name $name -Patterns $ExcludeFolders) {
        continue   # excluded entirely (company OneDrive) - counted nowhere
    }
    elseif ($name -like $OneDriveMatch) {
        $cat = 'UnmanagedOneDrive'
    }
    elseif ($knownPathMap.ContainsKey($full)) {
        $cat = $knownPathMap[$full]                       # path-resolved (locale proof)
    }
    elseif (Test-NameInList -Name $name -List $KnownFolders)     { $cat = 'Known' }
    elseif (Test-NameInList -Name $name -List $SupportedFolders) { $cat = 'Supported' }
    elseif (Test-NameInList -Name $name -List $LegacyFolders)    { $cat = 'Legacy' }
    else {
        $cat = 'Other'                                    # user-created = migration signal
    }

    # --- Measure and accumulate ---------------------------------------------------
    $usage = Get-FolderUsage -Path $dir.FullName
    $buckets[$cat].Bytes += $usage.Bytes
    $buckets[$cat].Items += $usage.Count
    $buckets[$cat].Names.Add($name)
    $totalBytes          += $usage.Bytes
}

# Combined-total threshold flag.
$totalOver    = ($totalBytes / 1GB) -ge $CapacityThresholdGB
$overValue    = $(if ($totalOver) { 'Yes' } else { 'No' })
$collectedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

#endregion -------------------------------------------------------------------------


#region ---------------------------- OUTPUT ----------------------------------------

# Build a SINGLE flat JSON object => ONE ROW PER DEVICE. Fixed category columns keep the
# columns identical across devices; discovered names ride along as sorted delimited
# strings (not JSON arrays), so the Power BI JSON transform stays flat.
$overColumn = "Over${CapacityThresholdGB}GB"

$record = [ordered]@{
    DeviceName        = $env:COMPUTERNAME
    UserName          = $env:USERNAME
    CollectionTimeUtc = $collectedUtc
    ParentFolderPath  = $resolvedRoot
}

foreach ($b in $BucketOrder) {
    $acc         = $buckets[$b]
    $sortedNames = $acc.Names | Sort-Object
    $record["${b}_SizeMB"]       = [math]::Round($acc.Bytes / 1MB, 2)
    $record["${b}_SizeGB"]       = [math]::Round($acc.Bytes / 1GB, 2)
    $record["${b}_ItemCount"]    = $acc.Items
    $record["${b}_FolderCount"]  = $acc.Names.Count
    $record["${b}_FoldersFound"] = ($sortedNames -join '; ')
}

$record['TotalSizeMB'] = [math]::Round($totalBytes / 1MB, 2)
$record['TotalSizeGB'] = [math]::Round($totalBytes / 1GB, 2)
$record[$overColumn]   = $overValue

# Compact, single-line JSON object for the Intune detection-output column.
Write-Output (([pscustomobject]$record) | ConvertTo-Json -Depth 3 -Compress)

# Reporting only - never flag the device.
exit 0

#endregion -------------------------------------------------------------------------
