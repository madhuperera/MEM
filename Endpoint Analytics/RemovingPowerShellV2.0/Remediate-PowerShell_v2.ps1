[bool] $ExitWithNoError = $false

if (Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowershellv2)
{
    Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root
    $ExitWithNoError
}