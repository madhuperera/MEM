[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$DotNET_V3 = Get-WindowsOptionalFeature -Online -FeatureName NetFx3

if ($DotNET_V3)
{
    $State_Of_DotNET_V3 = $DotNET_V3.State
    if ($State_Of_DotNET_V3 -like "*Enabled*")
    {
        Write-Output "ALERT: .NET v3.5 is enabled"
        exit $ExitWithError
    }

    Write-Output "WARNING: .NET v3.5 is NOT enabled but in the state $State_Of_PShell_v2"
    exit $ExitWithNoError
}
else
{
    Write-Output "GOOD: .NET v3.5 is not found"
    exit $ExitWithNoError
}