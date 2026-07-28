<#
.SYNOPSIS
    Removes a machine-wide (all-user) installation of Google Chrome, including
    shortcuts and (where safe) the shared Google Update component.

.DESCRIPTION
    This remediation script finds a machine-wide Google Chrome installation via the
    HKLM uninstall registry keys, stops running Chrome processes, runs Chrome's own
    silent uninstaller using the UninstallString recorded in the registry, and cleans
    up any leftover install directory and shortcuts.

    Google Update (the shared updater used by other Google applications such as
    Google Drive or Google Earth) is only removed if no other Google-published
    application remains installed on the device — this avoids breaking auto-update
    for unrelated Google software.

    Run Context: SYSTEM

.NOTES
    Author: madhuperera
    Requirements: Windows 10/11, PowerShell 5.1+, SYSTEM context

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Remediate-GoogleChrome.ps1
#>

$ErrorActionPreference = "Stop"

$S_UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome"
)

$S_BinaryPaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)

$S_InstallDirs = @(
    "$env:ProgramFiles\Google\Chrome",
    "${env:ProgramFiles(x86)}\Google\Chrome"
)

$S_UpdateDirs = @(
    "$env:ProgramFiles\Google\Update",
    "${env:ProgramFiles(x86)}\Google\Update"
)

$S_Shortcuts = @(
    "$env:Public\Desktop\Google Chrome.lnk",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"
)

$S_UpdateServices = @("gupdate", "gupdatem")
$S_UpdateTasks = @("GoogleUpdateTaskMachineCore", "GoogleUpdateTaskMachineUA")

function Test-ChromeInstalled
{
    foreach ($Path in $S_UninstallPaths)
    {
        if (Test-Path $Path)
        {
            $DisplayName = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).DisplayName
            if ($DisplayName -like "Google Chrome*") { return $true }
        }
    }
    foreach ($Path in $S_BinaryPaths)
    {
        if (Test-Path $Path) { return $true }
    }
    return $false
}

function Get-UninstallInvocation
{
    param([string]$F_UninstallString)

    # MSI-based installs (e.g. the Chrome Enterprise MSI) register an UninstallString
    # like "MsiExec.exe /X{GUID}" rather than a setup.exe path — this needs msiexec's
    # own silent switches, not the Chrome installer's --force-uninstall flag.
    if ($F_UninstallString -match '(?i)msiexec(\.exe)?\s+/[Ix]\s*(\{[0-9A-Fa-f\-]+\})')
    {
        return [PSCustomObject]@{ Exe = "msiexec.exe"; Args = "/X$($matches[2]) /qn /norestart" }
    }

    if ($F_UninstallString -match '"([^"]+)"(.*)$')
    {
        $F_Exe = $matches[1]
        $F_Args = $matches[2].Trim()
    }
    else
    {
        $F_Parts = $F_UninstallString.Split(" ", 2)
        $F_Exe = $F_Parts[0]
        $F_Args = if ($F_Parts.Count -gt 1) { $F_Parts[1] } else { "" }
    }

    return [PSCustomObject]@{ Exe = $F_Exe; Args = "$F_Args --force-uninstall".Trim() }
}

try
{
    if (-not (Test-ChromeInstalled))
    {
        Write-Output "No machine-wide Google Chrome installation found. Nothing to remediate."
        exit 0
    }

    # Stop running Chrome processes so files aren't locked during uninstall
    Write-Output "Stopping Chrome processes..."
    Stop-Process -Name "chrome", "GoogleCrashHandler", "GoogleCrashHandler64" -Force -ErrorAction SilentlyContinue

    # Run Chrome's own uninstaller via the registry UninstallString
    foreach ($Path in $S_UninstallPaths)
    {
        if (-not (Test-Path $Path)) { continue }

        $Props = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
        if ($Props.DisplayName -notlike "Google Chrome*") { continue }

        $F_UninstallString = $Props.UninstallString
        if ([string]::IsNullOrWhiteSpace($F_UninstallString))
        {
            Write-Output "No UninstallString found at $Path, will rely on directory cleanup instead."
            continue
        }

        $F_Parsed = Get-UninstallInvocation -F_UninstallString $F_UninstallString

        Write-Output "Running uninstaller: $($F_Parsed.Exe) $($F_Parsed.Args)"
        try
        {
            Start-Process -FilePath $F_Parsed.Exe -ArgumentList $F_Parsed.Args -Wait -PassThru -ErrorAction Stop | Out-Null
        }
        catch
        {
            Write-Output "Uninstaller invocation failed for $Path : $_"
        }
    }

    # Post-check: remove any orphaned install directory left behind, but only if
    # chrome.exe itself is actually gone (never force-delete a live install)
    foreach ($Dir in $S_InstallDirs)
    {
        $F_ChromeExe = Join-Path $Dir "Application\chrome.exe"
        if ((Test-Path $Dir) -and -not (Test-Path $F_ChromeExe))
        {
            Write-Output "Removing residual install directory: $Dir"
            Remove-Item -Path $Dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Remove shortcuts
    foreach ($Shortcut in $S_Shortcuts)
    {
        if (Test-Path $Shortcut)
        {
            Write-Output "Removing shortcut: $Shortcut"
            Remove-Item -Path $Shortcut -Force -ErrorAction SilentlyContinue
        }
    }

    # Verify Chrome is actually gone before touching the shared Google Update
    # component — if removal failed, Chrome's own entry would otherwise be excluded
    # from the "other Google apps" scan below and Update could be deleted out from
    # under a still-installed Chrome.
    if (Test-ChromeInstalled)
    {
        Write-Error "Remediation incomplete: Google Chrome still detected machine-wide."
        exit 1
    }

    # Guarded Google Update cleanup: only remove the shared updater if no other
    # Google-published application remains installed machine-wide
    $F_OtherGoogleApps = @()
    $F_AllUninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($Root in $F_AllUninstallRoots)
    {
        if (-not (Test-Path $Root)) { continue }

        Get-ChildItem -Path $Root -ErrorAction SilentlyContinue | ForEach-Object {
            $Props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if ($Props.Publisher -like "Google*" -and $Props.DisplayName -notlike "Google Chrome*")
            {
                $F_OtherGoogleApps += $Props.DisplayName
            }
        }
    }

    if ($F_OtherGoogleApps.Count -eq 0)
    {
        Write-Output "No other Google applications found. Cleaning up Google Update."

        Stop-Service -Name $S_UpdateServices -Force -ErrorAction SilentlyContinue
        foreach ($Service in $S_UpdateServices)
        {
            if (Get-Service -Name $Service -ErrorAction SilentlyContinue)
            {
                sc.exe delete $Service | Out-Null
            }
        }

        foreach ($Task in $S_UpdateTasks)
        {
            Unregister-ScheduledTask -TaskName $Task -Confirm:$false -ErrorAction SilentlyContinue
        }

        foreach ($Dir in $S_UpdateDirs)
        {
            if (Test-Path $Dir)
            {
                Remove-Item -Path $Dir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    else
    {
        Write-Output "Skipping Google Update cleanup: other Google app(s) present: $($F_OtherGoogleApps -join ', ')"
    }

    Write-Output "Remediation complete: Google Chrome removed machine-wide."
    exit 0
}
catch
{
    Write-Error "Remediation failed: $_"
    exit 1
}
