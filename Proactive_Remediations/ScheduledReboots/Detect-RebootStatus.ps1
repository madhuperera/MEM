# Detect-RebootStatus.ps1
# This script checks if the device has been rebooted in the last 7 days.

# Get the last boot time of the system
try
{
    $LastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
}
catch
{
    Write-Output "ERROR - Failed to get the last boot time. Exiting script with success to avoid false positives."
    exit 0
}

# Calculate the difference in days between now and the last boot time
$Days = ((Get-Date) - $LastBootTime).Days

# Check if the system was rebooted within the last 7 days
if ($Days -le 7)
{
    Write-Output "$($LastBootTime): The device has been rebooted in the last 7 days"
    Exit 0
} 
else
{
    Write-Output "$($LastBootTime): The device has NOT been rebooted in the last 7 days."
    Exit 1
}