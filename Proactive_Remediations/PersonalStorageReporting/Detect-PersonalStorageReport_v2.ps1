<#
.SYNOPSIS
    Personal Storage Reporting v2 - Intune Remediation DETECTION script (reporting only).

.DESCRIPTION
    Measures the size and file count of storage under the user profile and emits a SINGLE
    flat JSON object (one record per device) to STDOUT. Two kinds of targets:

      * Exact subfolders  ($SubFolders)   - measured by exact name, one column set each
                                             (<Name>_SizeMB, <Name>_SizeGB, <Name>_ItemCount).
      * Wildcard groups   ($FolderGroups) - a chosen Label + a Match pattern (e.g.
                                             'OneDrive*'). EVERY folder matching the pattern
                                             (minus $ExcludeFolders) is SUMMED into one
                                             column set under the Label, regardless of how
                                             many folders match or what they are named. The
                                             actual names found are listed in a companion
                                             column. This keeps columns identical across
                                             devices even when folder names differ
                                             ("OneDrive", "OneDrive - Personal", etc.).

    Intune captures this output in the "Pre-remediation detection output" column; parsing
    it as JSON in Power BI / Excel yields ONE ROW PER DEVICE.

    This script takes NO remediation action and ALWAYS exits 0. It never flags a device
    as non-compliant - it is purely a reporting collector.

    Runs in USER context so it can read the signed-in user's profile / OneDrive paths.
    Targets Windows PowerShell 5.1 (the Intune Management Extension default).

.NOTES
    Author : Madhu Perera
    Output : Single-line JSON object to STDOUT (one row per device). Keep the target list
             modest so the total stays < 2048 chars for the Intune column.
    OneDrive: .Length reports the logical size of online-only files without hydrating
              them, so Files On-Demand content is reported without being downloaded.
#>

#region ---------------------------- CONFIG ----------------------------------------

# Root folder that the targets live under. Supports environment variables.
$RootFolderPath = "$env:USERPROFILE"

# Exact-name subfolders to measure. Each becomes <Name>_SizeMB/_SizeGB/_ItemCount.
$SubFolders = @(
    'Desktop',
    'Pictures',
    'Documents'
)

# Wildcard groups. Each entry:
#   Label = the (stable) column prefix you choose - never derived from the folder name.
#   Match = a name pattern (supports * and ?) matched against direct children of the root.
# ALL matching folders (after $ExcludeFolders) are SUMMED into the Label's columns, and
# their names are listed in <Label>_FoldersFound with a <Label>_FolderCount.
$FolderGroups = @(
    @{ Label = 'UnmanagedOneDrive'; Match = 'OneDrive*' }
)

# Folder names / patterns to EXCLUDE from wildcard-group matches (supports * and ?).
# Use this to drop approved / OneDrive for Business folders so they are not reported.
# In a managed deployment the tenant name is known, e.g. 'OneDrive - Contoso'.
$ExcludeFolders = @(
    'OneDrive - Contoso'
)

# Capacity threshold in GB. Drives the "Over<N>GB" Yes/No column (checked against the
# COMBINED total of all targets - exact subfolders plus wildcard groups).
$CapacityThresholdGB = 1

#endregion -------------------------------------------------------------------------


#region ---------------------------- FUNCTIONS -------------------------------------

function Get-FolderUsage {
    <#
        Returns total bytes and file count for a folder (recursive).
        Tolerant of access-denied items and reparse points so one bad path
        does not break the whole report.
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

    return [pscustomobject]@{
        Bytes = $bytes
        Count = $count
    }
}

function Test-FolderExcluded {
    <#
        Returns $true if the folder name matches any of the exclude patterns
        (case-insensitive, supports * and ?).
    #>
    param(
        [string]  $Name,
        [string[]]$Patterns
    )

    foreach ($p in $Patterns) {
        if ($Name -like $p) { return $true }
    }
    return $false
}

#endregion -------------------------------------------------------------------------


#region ---------------------------- COLLECTION ------------------------------------

# Expand any environment variables in the configured root path.
$resolvedRoot = [System.Environment]::ExpandEnvironmentVariables($RootFolderPath)

$totalBytes = [int64]0

# --- Exact-name subfolders -------------------------------------------------------
$measured = New-Object System.Collections.Generic.List[object]

foreach ($name in $SubFolders) {

    $fullPath = Join-Path -Path $resolvedRoot -ChildPath $name
    $exists   = Test-Path -LiteralPath $fullPath -PathType Container

    if ($exists) {
        $usage = Get-FolderUsage -Path $fullPath
        $bytes = $usage.Bytes
        $items = $usage.Count
    }
    else {
        $bytes = [int64]0
        $items = 0
    }

    $totalBytes += $bytes

    $measured.Add([pscustomobject]@{
        Name  = $name
        Bytes = $bytes
        Items = $items
    })
}

# --- Wildcard groups (summed) ----------------------------------------------------
$groups = New-Object System.Collections.Generic.List[object]

foreach ($g in $FolderGroups) {

    $groupBytes = [int64]0
    $groupItems = 0
    $foundNames = New-Object System.Collections.Generic.List[string]

    # Match direct children of the root by pattern. -Filter is case-insensitive on Windows.
    $dirs = Get-ChildItem -LiteralPath $resolvedRoot -Directory -Filter $g.Match -Force -ErrorAction SilentlyContinue

    foreach ($d in $dirs) {

        if (Test-FolderExcluded -Name $d.Name -Patterns $ExcludeFolders) { continue }

        $usage       = Get-FolderUsage -Path $d.FullName
        $groupBytes += $usage.Bytes
        $groupItems += $usage.Count
        $foundNames.Add($d.Name)
    }

    $totalBytes += $groupBytes

    # Sort names alphabetically (case-insensitive) so the output string is deterministic,
    # then join into a single delimited STRING (not a JSON array) - a scalar text column
    # keeps the Power BI JSON transform flat with no nested list to expand.
    $sortedNames = $foundNames | Sort-Object

    $groups.Add([pscustomobject]@{
        Label = $g.Label
        Bytes = $groupBytes
        Items = $groupItems
        Names = ($sortedNames -join '; ')
        Count = $foundNames.Count
    })
}

# OverThreshold is evaluated against the COMBINED total of all targets.
$totalOver    = ($totalBytes / 1GB) -ge $CapacityThresholdGB
$overValue    = $(if ($totalOver) { 'Yes' } else { 'No' })
$collectedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$totalSizeMB  = [math]::Round($totalBytes / 1MB, 2)
$totalSizeGB  = [math]::Round($totalBytes / 1GB, 2)

#endregion -------------------------------------------------------------------------


#region ---------------------------- OUTPUT ----------------------------------------

# Build a SINGLE flat JSON object for the device. Parsing it as JSON in Power BI / Excel
# yields ONE ROW PER DEVICE - no array, no nested lists, no row-per-folder explosion.
$overColumn = "Over${CapacityThresholdGB}GB"

$record = [ordered]@{
    DeviceName        = $env:COMPUTERNAME
    UserName          = $env:USERNAME
    CollectionTimeUtc = $collectedUtc
    ParentFolderPath  = $resolvedRoot
}

# Exact-name subfolder columns (v1-compatible).
foreach ($f in $measured) {
    $record["$($f.Name)_SizeMB"]    = [math]::Round($f.Bytes / 1MB, 2)
    $record["$($f.Name)_SizeGB"]    = [math]::Round($f.Bytes / 1GB, 2)
    $record["$($f.Name)_ItemCount"] = $f.Items
}

# Wildcard-group columns (summed, with the discovered names listed).
foreach ($gr in $groups) {
    $record["$($gr.Label)_SizeMB"]       = [math]::Round($gr.Bytes / 1MB, 2)
    $record["$($gr.Label)_SizeGB"]       = [math]::Round($gr.Bytes / 1GB, 2)
    $record["$($gr.Label)_ItemCount"]    = $gr.Items
    $record["$($gr.Label)_FoldersFound"] = $gr.Names
    $record["$($gr.Label)_FolderCount"]  = $gr.Count
}

$record['TotalSizeMB'] = $totalSizeMB
$record['TotalSizeGB'] = $totalSizeGB
$record[$overColumn]   = $overValue

# Compact, single-line JSON object for the Intune detection-output column.
Write-Output (([pscustomobject]$record) | ConvertTo-Json -Depth 3 -Compress)

# Reporting only - never flag the device.
exit 0

#endregion -------------------------------------------------------------------------
