[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

if (Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowershellv2)
{
    exit $ExitWithError
}
else
{
    exit $ExitWithNoError
}