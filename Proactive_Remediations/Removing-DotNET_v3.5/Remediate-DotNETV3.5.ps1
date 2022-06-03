[bool] $ExitWithNoError = $false

if ((Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State -like "*Enabled*")
{
    Disable-WindowsOptionalFeature -Online -FeatureName NetFx3
    $ExitWithNoError
}