<#
.SYNOPSIS
    Removes all L2TP VPN connections from the current user's phonebook.

.DESCRIPTION
    This remediation script finds all VPN connections using the L2TP tunnel type in the current
    user's VPN phonebook. It disconnects any active connections first, then removes them.

    Run Context: User (logged-in user)

.NOTES
    Author: madhuperera
    Requirements: Windows 10/11, PowerShell 5.1+, user-level permissions

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Remediate-L2TPVPN.ps1
#>

$ErrorActionPreference = "Stop"

try
{
    # Get all user-level VPN connections with L2TP tunnel type
    $L2tpConnections = Get-VpnConnection -ErrorAction SilentlyContinue |
        Where-Object { $_.TunnelType -eq "L2tp" }

    if (-not $L2tpConnections)
    {
        Write-Output "No L2TP VPN connections found in user phonebook. Nothing to remediate."
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
            Remove-VpnConnection -Name $VpnName -Force -ErrorAction Stop
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

    Write-Output "Remediation complete: All L2TP VPN connections removed from user phonebook."
    exit 0
}
catch
{
    Write-Error "Remediation failed: $_"
    exit 1
}
