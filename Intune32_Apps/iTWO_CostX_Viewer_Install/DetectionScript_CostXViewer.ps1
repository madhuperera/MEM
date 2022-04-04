[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$CostX_Viewer_FilePath = "C:\Program Files\Exactal\CostXView\CostXView.exe"

if (Test-Path -Path $CostX_Viewer_FilePath -Type Leaf)
{
    $InstalledVersion = (Get-ItemProperty -Path $CostX_Viewer_FilePath).VersionInfo
    if ($InstalledVersion)
    {
        if ($InstalledVersion.ProductVersion -gt 7.0)
        {
            Write-Output "CostX Viewer is up-to-date"
            exit $ExitWithNoError
        }
        else
        {
            Write-Output "CostX Viewer is not up-to-date"
            exit $ExitWithError
        }
    }
}
else
{
    Write-Output "CostX Viewer is not installed"
    exit $ExitWithError
}