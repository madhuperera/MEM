<#
.SYNOPSIS
    Removes all ScreenConnect Client instances EXCEPT the one(s) passed via -KeepInstanceId.

.DESCRIPTION
    Packaged as an Intune Win32 app and used as the *install* command. Although Intune
    treats it as an install, its actual job is to UNINSTALL unwanted ScreenConnect Client
    instances (e.g. a legacy/old server) while preserving the RMM-managed instance.

    ScreenConnect stamps a unique 16-hex instance ID into the client DisplayName, service
    name and install folder, e.g.  "ScreenConnect Client (a1b2c3d4e5f6a7b8)".
    That ID is identical on every device for a given server instance, so we KEEP the
    RMM instance ID and remove everything else (self-healing "keep-list" strategy).

.PARAMETER KeepInstanceId
    One or more 16-hex instance IDs to PRESERVE. Supply the RMM instance ID here via the
    Intune install command line, e.g.:
        powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Uninstall-OldScreenConnect.ps1 -KeepInstanceId a1b2c3d4e5f6a7b8
    Multiple allowed:  -KeepInstanceId a1b2c3d4e5f6a7b8,00112233445566ff

.NOTES
    SAFETY: If no KeepInstanceId is supplied, the script ABORTS without removing anything,
    so a missing parameter can never wipe the RMM client.

    Exit codes:  0 = success (or nothing to remove)   1 = failure / aborted
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]] $KeepInstanceId = @()
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
$LogDir = 'C:\ProgramData\ScreenConnectCleanup'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogDir 'Uninstall-OldScreenConnect.log'

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    $line = "{0}  [{1}]  {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Output $line
    Add-Content -Path $LogFile -Value $line
}

# ---------------------------------------------------------------------------
# Normalise + guard the keep-list
# ---------------------------------------------------------------------------
$Keep = @($KeepInstanceId | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLower() })

Write-Log "=== ScreenConnect old-instance removal started ==="
Write-Log ("Keep-list (preserve these IDs): {0}" -f ($(if ($Keep) { $Keep -join ', ' } else { '<empty>' })))

if ($Keep.Count -eq 0) {
    Write-Log "No -KeepInstanceId supplied. Aborting to avoid removing the RMM-managed client." 'ERROR'
    exit 1
}

# ---------------------------------------------------------------------------
# Enumerate installed ScreenConnect Client instances (both registry views)
# ---------------------------------------------------------------------------
function Get-ScreenConnectInstances {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $roots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'ScreenConnect Client*' } |
            ForEach-Object {
                $instanceId = $null
                if ($_.DisplayName -match '\(([0-9a-fA-F]{16})\)') { $instanceId = $Matches[1].ToLower() }
                $guid = $null
                if ($_.UninstallString -match '(\{[0-9A-Fa-f\-]{36}\})') { $guid = $Matches[1] }

                [pscustomobject]@{
                    DisplayName     = $_.DisplayName
                    InstanceId      = $instanceId
                    ProductCode     = $guid
                    UninstallString = $_.UninstallString
                    RegistryKey     = $_.PSPath
                }
            }
    }
}

$instances = @(Get-ScreenConnectInstances)
Write-Log ("Found {0} ScreenConnect Client instance(s)." -f $instances.Count)
foreach ($i in $instances) {
    Write-Log ("  - '{0}'  (ID: {1})" -f $i.DisplayName, $(if ($i.InstanceId) { $i.InstanceId } else { 'UNKNOWN' }))
}

# ---------------------------------------------------------------------------
# Removal helpers
# ---------------------------------------------------------------------------
function Remove-Instance {
    param([pscustomobject] $Instance)

    $ok = $true

    # 1) MSI uninstall (preferred)
    if ($Instance.ProductCode) {
        Write-Log ("Uninstalling via MSI product code {0}" -f $Instance.ProductCode)
        $args = "/x $($Instance.ProductCode) /qn /norestart"
        $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $args -Wait -PassThru
        if ($p.ExitCode -in @(0, 1605, 3010)) {
            Write-Log ("  msiexec exit code {0} (success)" -f $p.ExitCode)
        } else {
            Write-Log ("  msiexec exit code {0} (non-success)" -f $p.ExitCode) 'WARN'
            $ok = $false
        }
    }
    elseif ($Instance.UninstallString) {
        Write-Log ("No product code; running raw UninstallString: {0}" -f $Instance.UninstallString) 'WARN'
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$($Instance.UninstallString) /qn /norestart`"" -Wait -PassThru
        Write-Log ("  UninstallString exit code {0}" -f $p.ExitCode)
    }
    else {
        Write-Log "  No uninstall method found in registry; relying on service/folder cleanup." 'WARN'
    }

    # 2) Fallback cleanup for this instance only (service + folder)
    if ($Instance.InstanceId) {
        $svcName = "ScreenConnect Client ($($Instance.InstanceId))"
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Log ("  Stopping + deleting leftover service '{0}'" -f $svcName)
            try { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue } catch {}
            & sc.exe delete "$svcName" | Out-Null
        }

        $folder = Join-Path ${env:ProgramFiles(x86)} "ScreenConnect Client ($($Instance.InstanceId))"
        if (Test-Path $folder) {
            Write-Log ("  Removing leftover folder '{0}'" -f $folder)
            try { Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    return $ok
}

# ---------------------------------------------------------------------------
# Process each instance
# ---------------------------------------------------------------------------
$overallOk = $true
$removedCount = 0

foreach ($inst in $instances) {
    if ($inst.InstanceId -and ($Keep -contains $inst.InstanceId)) {
        Write-Log ("KEEP  -> '{0}' (on keep-list, left untouched)" -f $inst.DisplayName)
        continue
    }
    if (-not $inst.InstanceId) {
        Write-Log ("SKIP  -> '{0}' (could not parse instance ID; NOT removing to stay safe)" -f $inst.DisplayName) 'WARN'
        continue
    }

    Write-Log ("REMOVE-> '{0}' (not on keep-list)" -f $inst.DisplayName)
    if (Remove-Instance -Instance $inst) { $removedCount++ } else { $overallOk = $false }
}

Write-Log ("Removal complete. Removed: {0}. Success: {1}." -f $removedCount, $overallOk)
Write-Log "=== ScreenConnect old-instance removal finished ==="

if ($overallOk) { exit 0 } else { exit 1 }
