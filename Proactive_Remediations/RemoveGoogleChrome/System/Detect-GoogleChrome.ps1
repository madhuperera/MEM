<#
.SYNOPSIS
    Detects if Google Chrome is installed machine-wide (all-user) on the device.

.DESCRIPTION
    This detection script checks the machine-wide uninstall registry keys and the
    Program Files install locations for a machine-wide Google Chrome installation.
    If any evidence of a machine-wide install is found, the script returns
    non-compliant (exit 1) to trigger remediation.

    Run Context: SYSTEM

.NOTES
    Author: madhuperera
    Requirements: Windows 10/11, PowerShell 5.1+, SYSTEM context

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-GoogleChrome.ps1
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

try
{
    $F_Evidence = @()

    foreach ($Path in $S_UninstallPaths)
    {
        if (Test-Path $Path)
        {
            $DisplayName = (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue).DisplayName
            if ($DisplayName -like "Google Chrome*")
            {
                $F_Evidence += "Registry key: $Path"
            }
        }
    }

    foreach ($Path in $S_BinaryPaths)
    {
        if (Test-Path $Path)
        {
            $F_Evidence += "Binary: $Path"
        }
    }

    if ($F_Evidence.Count -gt 0)
    {
        Write-Output "Non-Compliant: Google Chrome found machine-wide. Evidence: $($F_Evidence -join '; ')"
        exit 1
    }
    else
    {
        Write-Output "Compliant: No machine-wide Google Chrome installation found."
        exit 0
    }
}
catch
{
    Write-Error "Detection failed: $_"
    exit 1
}
