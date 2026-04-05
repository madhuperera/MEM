<#
.SYNOPSIS
    Detects if any L2TP VPN connections exist in the system (all-user) phonebook.

.DESCRIPTION
    This detection script checks for the presence of any VPN connections using the L2TP tunnel type
    in the system-wide (all-user) VPN phonebook. If any L2TP connections are found, the script
    returns non-compliant (exit 1) to trigger remediation.

    Run Context: SYSTEM

.NOTES
    Author: madhuperera
    Requirements: Windows 10/11, PowerShell 5.1+, SYSTEM context

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-L2TPVPN.ps1
#>

$ErrorActionPreference = "Stop"

try
{
    # Get all system-wide VPN connections with L2TP tunnel type
    $L2tpConnections = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue |
        Where-Object { $_.TunnelType -eq "L2tp" }

    if ($L2tpConnections)
    {
        $Names = ($L2tpConnections | Select-Object -ExpandProperty Name) -join ", "
        Write-Output "Non-Compliant: Found L2TP VPN connection(s) in system phonebook: $Names"
        exit 1
    }
    else
    {
        Write-Output "Compliant: No L2TP VPN connections found in system phonebook."
        exit 0
    }
}
catch
{
    Write-Error "Detection failed: $_"
    exit 1
}
