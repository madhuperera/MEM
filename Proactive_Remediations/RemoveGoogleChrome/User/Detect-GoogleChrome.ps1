<#
.SYNOPSIS
    Detects if Google Chrome is installed for the current user.

.DESCRIPTION
    This detection script checks the current user's uninstall registry key and
    per-user install location for a Google Chrome installation. If any evidence
    of a per-user install is found, the script returns non-compliant (exit 1)
    to trigger remediation.

    Run Context: User (logged-in user)

.NOTES
    Author: madhuperera
    Requirements: Windows 10/11, PowerShell 5.1+, user-level permissions

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-GoogleChrome.ps1
#>

$ErrorActionPreference = "Stop"

$S_UninstallPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome"
$S_BinaryPath = "$env:LocalAppData\Google\Chrome\Application\chrome.exe"

try
{
    $F_Evidence = @()

    if (Test-Path $S_UninstallPath)
    {
        $DisplayName = (Get-ItemProperty -Path $S_UninstallPath -ErrorAction SilentlyContinue).DisplayName
        if ($DisplayName -like "Google Chrome*")
        {
            $F_Evidence += "Registry key: $S_UninstallPath"
        }
    }

    if (Test-Path $S_BinaryPath)
    {
        $F_Evidence += "Binary: $S_BinaryPath"
    }

    if ($F_Evidence.Count -gt 0)
    {
        Write-Output "Non-Compliant: Google Chrome found for current user. Evidence: $($F_Evidence -join '; ')"
        exit 1
    }
    else
    {
        Write-Output "Compliant: No per-user Google Chrome installation found."
        exit 0
    }
}
catch
{
    Write-Error "Detection failed: $_"
    exit 1
}
