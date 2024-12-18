# Define the list of SSIDs to block
$BlockedSSIDs = @("BlockMe-Guest", "BlockMe-Public") # Replace with actual SSIDs to block

# Get the list of SSIDs currently in the block list
$BlockListFilters = netsh wlan show filters permission=block | Select-String -Pattern "SSID:" | ForEach-Object {($_ -split ":")[1] -replace '"', '' -replace ',.*', '' -replace '^\s+', ''}

# Check if all required SSIDs are blocked
$UnblockedSSIDs = $BlockedSSIDs | Where-Object { $_ -notin $BlockListFilters }

if ($UnblockedSSIDs.Count -eq 0)
{
    Write-Output "Compliant: All specified SSIDs are blocked."
    exit 0 # Compliant
}
else
{
    Write-Output "Non-Compliant: The following SSIDs are not blocked: $($UnblockedSSIDs -join ', ')"
    exit 1 # Non-compliant
}
