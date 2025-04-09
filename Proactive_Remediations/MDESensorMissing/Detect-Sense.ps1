# Detection Script: Check if the 'Sense' service exists on the device

try 
{
    # Attempt to retrieve the Sense service
    $SenseService = Get-Service -Name 'Sense' -ErrorAction Stop

    Write-Output "$($SenseService.DisplayName) is installed on the device. Current Status is $($SenseService.Status)"
    Exit 0
}
catch 
{
    # If an error occurs, output a message and exit with code 1
    Write-Output "MDE Sensor not installed on the device."
    Exit 1
}
