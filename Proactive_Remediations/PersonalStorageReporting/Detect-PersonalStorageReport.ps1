<#
.SYNOPSIS
    Personal Storage Reporting - Intune Remediation DETECTION script (reporting only).

.DESCRIPTION
    Measures the size and file count of a defined list of subfolders beneath a root
    folder path and emits a SINGLE flat JSON object (one record per device) to STDOUT.
    Each subfolder contributes its own columns (<Name>_SizeMB, <Name>_SizeGB,
    <Name>_ItemCount). Intune captures this output in the "Pre-remediation detection
    output" column; parsing it as JSON in Power BI / Excel yields ONE ROW PER DEVICE.

    This script takes NO remediation action and ALWAYS exits 0. It never flags a device
    as non-compliant - it is purely a reporting collector.

    Runs in USER context so it can read the signed-in user's profile / OneDrive paths.
    Targets Windows PowerShell 5.1 (the Intune Management Extension default).

.NOTES
    Author : Madhu Perera
    Output : Single-line JSON object to STDOUT (one row per device). Each subfolder adds
             ~60 chars; keep the list modest so the total stays < 2048 chars for Intune.
    OneDrive: .Length reports the logical size of online-only files without hydrating
              them, so Files On-Demand content is reported without being downloaded.
#>

#region ---------------------------- CONFIG ----------------------------------------

# Root folder that the subfolders live under. Supports environment variables.
$RootFolderPath = "$env:USERPROFILE"

# Explicit list of subfolder names (direct children of $RootFolderPath) to measure.
$SubFolders = @(
    'Desktop',
    'Pictures',
    'Documents'
)

# Capacity threshold in GB. Drives the "Over<N>GB" Yes/No column (checked against the
# COMBINED total of all subfolders, not any individual folder).
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

#endregion -------------------------------------------------------------------------


#region ---------------------------- COLLECTION ------------------------------------

# Expand any environment variables in the configured root path.
$resolvedRoot = [System.Environment]::ExpandEnvironmentVariables($RootFolderPath)

# First pass: measure each subfolder and accumulate the combined total.
$measured    = New-Object System.Collections.Generic.List[object]
$totalBytes  = [int64]0

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
        Name   = $name
        Exists = $exists
        Bytes  = $bytes
        Items  = $items
    })
}

# OverThreshold is evaluated against the COMBINED total of all in-scope subfolders,
# not any individual folder. It is a single device-level flag.
$totalOver     = ($totalBytes / 1GB) -ge $CapacityThresholdGB
$overValue     = $(if ($totalOver) { 'Yes' } else { 'No' })
$collectedUtc  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$totalSizeMB   = [math]::Round($totalBytes / 1MB, 2)
$totalSizeGB   = [math]::Round($totalBytes / 1GB, 2)

#endregion -------------------------------------------------------------------------


#region ---------------------------- OUTPUT ----------------------------------------

# Output a SINGLE flat JSON object for the device. Each subfolder contributes its own
# columns (<Name>_SizeMB, <Name>_SizeGB, <Name>_ItemCount). When the detection-output
# column is parsed as JSON in Power BI / Excel it becomes one record = ONE ROW PER
# DEVICE - no array, no nested lists, no row-per-subfolder explosion.
$overColumn = "Over${CapacityThresholdGB}GB"

$record = [ordered]@{
    DeviceName        = $env:COMPUTERNAME
    UserName          = $env:USERNAME
    CollectionTimeUtc = $collectedUtc
    ParentFolderPath  = $resolvedRoot
}

foreach ($f in $measured) {
    $record["$($f.Name)_SizeMB"]    = [math]::Round($f.Bytes / 1MB, 2)
    $record["$($f.Name)_SizeGB"]    = [math]::Round($f.Bytes / 1GB, 2)
    $record["$($f.Name)_ItemCount"] = $f.Items
}

$record['TotalSizeMB'] = $totalSizeMB
$record['TotalSizeGB'] = $totalSizeGB
$record[$overColumn]   = $overValue

# Compact, single-line JSON object for the Intune detection-output column.
Write-Output (([pscustomobject]$record) | ConvertTo-Json -Depth 3 -Compress)

# Reporting only - never flag the device.
exit 0

#endregion -------------------------------------------------------------------------
