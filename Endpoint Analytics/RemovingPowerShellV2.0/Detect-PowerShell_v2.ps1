[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

if (Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowershellv2)
{
    if ((Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowershellv2).State -like "*Enabled*")
    {
        exit $ExitWithError
    }
    exit $ExitWithNoError
}
else
{
    exit $ExitWithNoError
}