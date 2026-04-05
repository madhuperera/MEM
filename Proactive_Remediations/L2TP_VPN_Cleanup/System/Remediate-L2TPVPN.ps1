<#
.SYNOPSIS
    Removes all L2TP VPN connections from the system (all-user) phonebook.

.DESCRIPTION
    This remediation script finds all VPN connections using the L2TP tunnel type in the system-wide
    (all-user) VPN phonebook. It disconnects any active connections first, then removes them.

    Run Context: SYSTEM

.NOTES
    Author: madhuperera
    Requirements: Windows 10/11, PowerShell 5.1+, SYSTEM context

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Remediate-L2TPVPN.ps1
#>

$ErrorActionPreference = "Stop"

try
{
    # Get all system-wide VPN connections with L2TP tunnel type
    $L2tpConnections = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue |
        Where-Object { $_.TunnelType -eq "L2tp" }

    if (-not $L2tpConnections)
    {
        Write-Output "No L2TP VPN connections found in system phonebook. Nothing to remediate."
        exit 0
    }

    $FailedRemovals = @()

    foreach ($Vpn in $L2tpConnections)
    {
        $VpnName = $Vpn.Name
        try
        {
            # Disconnect if currently connected
            if ($Vpn.ConnectionStatus -eq "Connected")
            {
                Write-Output "Disconnecting '$VpnName'..."
                rasdial $VpnName /DISCONNECT | Out-Null
                Start-Sleep -Seconds 3
            }

            # Remove the VPN connection
            Remove-VpnConnection -Name $VpnName -AllUserConnection -Force -ErrorAction Stop
            Write-Output "Successfully removed L2TP VPN: $VpnName"
        }
        catch
        {
            Write-Error "Failed to remove '$VpnName': $_"
            $FailedRemovals += $VpnName
        }
    }

    if ($FailedRemovals.Count -gt 0)
    {
        Write-Error "Remediation incomplete. Failed to remove: $($FailedRemovals -join ', ')"
        exit 1
    }

    Write-Output "Remediation complete: All L2TP VPN connections removed from system phonebook."
    exit 0
}
catch
{
    Write-Error "Remediation failed: $_"
    exit 1
}
