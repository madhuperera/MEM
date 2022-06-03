[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
[String] $NewVersionToDeployed = "15.30.3.0"

$TeamViewerQS_FilePath = "$ENV:PUBLIC\Desktop\TeamViewerQS.exe"

if (Test-Path -Path $TeamViewerQS_FilePath -Type Leaf)
{
    $InstalledVersion = (Get-ItemProperty -Path $TeamViewerQS_FilePath).VersionInfo.ProductVersionRaw
    if ($InstalledVersion)
    {
        if ($InstalledVersion -ge $NewVersionToDeployed)
        {
            Write-Output "TeamViewer QS is up-to-date"
            exit $ExitWithNoError
        }
        else
        {
            Write-Output "TeamViewer QS is not up-to-date"
            exit $ExitWithError
        }
    }
}
else
{
    Write-Output "TeamViewer QS is not installed"
    exit $ExitWithError
}