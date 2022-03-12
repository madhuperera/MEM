[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$PowerShell_V2 = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowershellv2

if ($PowerShell_V2)
{
    $State_Of_PShell_v2 = $PowerShell_V2.State
    if ($State_Of_PShell_v2 -like "*Enabled*")
    {
        Write-Output "ALERT: PowerShell v2.0 is enabled"
        exit $ExitWithError
    }

    Write-Output "WARNING: PowerShell v2.0 is NOT enabled but in the state $State_Of_PShell_v2"
    exit $ExitWithNoError
}
else
{
    Write-Output "GOOD: PowerShell v2.0 is not found"
    exit $ExitWithNoError
}