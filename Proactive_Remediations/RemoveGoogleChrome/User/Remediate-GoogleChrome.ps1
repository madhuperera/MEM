<#
.SYNOPSIS
    Removes the current user's per-user installation of Google Chrome, including
    all browsing data, shortcuts, and (where safe) the per-user Google Update
    component.

.DESCRIPTION
    This remediation script finds a per-user Google Chrome installation via the
    HKCU uninstall registry key, stops running Chrome processes, runs Chrome's own
    silent uninstaller using the UninstallString recorded in the registry, and then
    removes the entire per-user Chrome folder — including "User Data" (bookmarks,
    saved passwords, history, extensions). This is a full wipe, not a preserve-
    and-uninstall: browsing data is not recoverable after this script runs.

    Per-user Google Update (the shared updater used by other Google applications
    such as Google Drive or Google Earth) is only removed if no other Google-
    published application remains installed for the current user — this avoids
    breaking auto-update for unrelated Google software.

    Run Context: User (logged-in user)

.NOTES
    Author: madhuperera
    Requirements: Windows 10/11, PowerShell 5.1+, user-level permissions

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Remediate-GoogleChrome.ps1
#>

$ErrorActionPreference = "Stop"

$S_UninstallPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome"
$S_BinaryPath = "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
$S_ChromeDir = "$env:LocalAppData\Google\Chrome"
$S_UpdateDir = "$env:LocalAppData\Google\Update"

$S_Shortcuts = @(
    "$env:UserProfile\Desktop\Google Chrome.lnk",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"
)

function Test-ChromeInstalled
{
    if (Test-Path $S_UninstallPath)
    {
        $DisplayName = (Get-ItemProperty -Path $S_UninstallPath -ErrorAction SilentlyContinue).DisplayName
        if ($DisplayName -like "Google Chrome*") { return $true }
    }
    return (Test-Path $S_BinaryPath)
}

function Get-UninstallInvocation
{
    param([string]$F_UninstallString)

    # MSI-based installs register an UninstallString like "MsiExec.exe /X{GUID}"
    # rather than a setup.exe path — this needs msiexec's own silent switches, not
    # the Chrome installer's --force-uninstall flag.
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
        Write-Output "No per-user Google Chrome installation found. Nothing to remediate."
        exit 0
    }

    # Stop running Chrome processes so files aren't locked during uninstall
    Write-Output "Stopping Chrome processes..."
    Stop-Process -Name "chrome", "GoogleCrashHandler", "GoogleCrashHandler64" -Force -ErrorAction SilentlyContinue

    # Run Chrome's own uninstaller via the registry UninstallString
    if (Test-Path $S_UninstallPath)
    {
        $Props = Get-ItemProperty -Path $S_UninstallPath -ErrorAction SilentlyContinue
        $F_UninstallString = $Props.UninstallString

        if (-not [string]::IsNullOrWhiteSpace($F_UninstallString))
        {
            $F_Parsed = Get-UninstallInvocation -F_UninstallString $F_UninstallString

            Write-Output "Running uninstaller: $($F_Parsed.Exe) $($F_Parsed.Args)"
            try
            {
                Start-Process -FilePath $F_Parsed.Exe -ArgumentList $F_Parsed.Args -Wait -PassThru -ErrorAction Stop | Out-Null
            }
            catch
            {
                Write-Output "Uninstaller invocation failed: $_"
            }
        }
        else
        {
            Write-Output "No UninstallString found, will rely on directory cleanup instead."
        }
    }

    # Full removal: delete the entire per-user Chrome folder, including
    # "User Data" (bookmarks, saved passwords, history, extensions)
    if (Test-Path $S_ChromeDir)
    {
        Write-Output "Removing Chrome folder (including User Data): $S_ChromeDir"
        Remove-Item -Path $S_ChromeDir -Recurse -Force -ErrorAction SilentlyContinue
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
        Write-Error "Remediation incomplete: Google Chrome still detected for current user."
        exit 1
    }

    # Guarded per-user Google Update cleanup: only remove it if no other
    # Google-published application remains installed for this user
    $F_OtherGoogleApps = @()
    $F_UserUninstallRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"

    if (Test-Path $F_UserUninstallRoot)
    {
        Get-ChildItem -Path $F_UserUninstallRoot -ErrorAction SilentlyContinue | ForEach-Object {
            $Props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if ($Props.Publisher -like "Google*" -and $Props.DisplayName -notlike "Google Chrome*")
            {
                $F_OtherGoogleApps += $Props.DisplayName
            }
        }
    }

    if ($F_OtherGoogleApps.Count -eq 0)
    {
        Write-Output "No other Google applications found for this user. Cleaning up per-user Google Update."

        if (Test-Path $S_UpdateDir)
        {
            Remove-Item -Path $S_UpdateDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        try
        {
            # Google names per-user tasks with the user's own SID embedded in the
            # task name (e.g. "GoogleUpdateTaskUserS-1-5-21-...Core"), which is a
            # more reliable match than the task Principal's UserId property.
            $F_CurrentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            Get-ScheduledTask -TaskName "GoogleUpdateTaskUser$F_CurrentSid*" -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Output "Removing scheduled task: $($_.TaskName)"
                Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        catch
        {
            Write-Output "Could not enumerate/remove GoogleUpdateTaskUser* scheduled tasks: $_"
        }
    }
    else
    {
        Write-Output "Skipping per-user Google Update cleanup: other Google app(s) present: $($F_OtherGoogleApps -join ', ')"
    }

    Write-Output "Remediation complete: Google Chrome removed for current user."
    exit 0
}
catch
{
    Write-Error "Remediation failed: $_"
    exit 1
}
