[bool] $ExitWithNoError = $false

if ((Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowershellv2).State -like "*Enabled*")
{
    Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root
    $ExitWithNoError
}