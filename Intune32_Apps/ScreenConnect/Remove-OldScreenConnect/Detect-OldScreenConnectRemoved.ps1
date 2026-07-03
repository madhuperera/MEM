<#
.SYNOPSIS
    Intune Win32 detection rule for the "Remove Old ScreenConnect" app.

.DESCRIPTION
    "Detected" (exit 0 + STDOUT) means the removal SUCCEEDED, i.e. no unwanted
    ScreenConnect Client instances remain. Only the keep-listed RMM instance
    (or nothing at all) is allowed.

    - Unwanted instances present  -> exit 1, no output -> Intune = NOT detected
                                     -> Intune (re)runs the install command (the uninstaller).
    - Only keep-listed / none     -> exit 0 + output    -> Intune = detected (compliant).

    Intune runs detection scripts with no command line, so the keep-list cannot be a
    parameter here. Set it in the $KeepInstanceId variable below and keep it in sync with
    the -KeepInstanceId value used on the install command.
#>

# ===========================================================================
# EDIT ME: same 16-hex instance ID(s) passed as -KeepInstanceId on the install command.
# Multiple allowed, e.g. @('a1b2c3d4e5f6a7b8','00112233445566ff')
# ===========================================================================
$KeepInstanceId = @('<CHANHGE_ME_TO_THE_RMM_INSTANCE_ID>')
# ===========================================================================

$Keep = @($KeepInstanceId | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLower() })

# Nothing configured (still the placeholder / empty) -> report not detected so install runs.
if ($Keep.Count -eq 0 -or $Keep -contains 'replace_with_rmm_instance_id') { exit 1 }

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
                [pscustomobject]@{
                    DisplayName = $_.DisplayName
                    InstanceId  = $instanceId
                }
            }
    }
}

$instances = @(Get-ScreenConnectInstances)

# Anything not on the keep-list is "unwanted". An unparseable ID is treated as unwanted
# (conservative: if we cannot confirm it is the RMM instance, removal is not complete).
$unwanted = @($instances | Where-Object {
    (-not $_.InstanceId) -or (-not ($Keep -contains $_.InstanceId))
})

if ($unwanted.Count -eq 0) {
    Write-Output "Compliant: no unwanted ScreenConnect Client instances present."
    exit 0
}
else {
    # No STDOUT -> Intune treats as NOT detected -> install command re-runs.
    exit 1
}
