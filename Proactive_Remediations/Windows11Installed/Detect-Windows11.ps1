# Detect-Win11.ps1
# This script checks if the host is running Windows 11

# Get the OS version information
$OSVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Version

# Windows 11 major version starts with 10.0 and build number is 22000 or higher
if ([version]$OSVersion -gt [version]"10.0.22000")
{
    Write-Output "The host is running Windows 11."
    Exit 0
}
else
{
    Write-Output "The host is NOT running Windows 11."
    Exit 1
}