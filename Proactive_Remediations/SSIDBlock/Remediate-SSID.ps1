# Define the list of SSIDs to block
$BlockedSSIDs = @("BlockMe-Guest", "BlockMe-Public") # Replace with actual SSIDs to block

# Get the list of SSIDs currently in the block list
$BlockListFilters = netsh wlan show filters permission=block | Select-String -Pattern "SSID:" | ForEach-Object {($_ -split ":")[1] -replace '"', '' -replace ',.*', '' -replace '^\s+', ''}

# Find SSIDs that need to be added to the block list
$SSIDsToAdd = $BlockedSSIDs | Where-Object { $_ -notin $BlockListFilters }

# Add missing SSIDs to the block list
foreach ($SSID in $SSIDsToAdd)
{
    try
    {
        netsh wlan add filter permission=block ssid=$SSID networktype=infrastructure
        Write-Output "Successfully added SSID to block list: $SSID"
    }
    catch
    {
        Write-Error "Failed to add SSID: $SSID. Error: $_"
    }
}

# Final status check
if ($SSIDsToAdd.Count -eq 0)
{
    Write-Output "Remediation complete: All specified SSIDs are already in the block list."
}
else
{
    Write-Output "Remediation complete: Added the following SSIDs to the block list: $($SSIDsToAdd -join ', ')"
}
