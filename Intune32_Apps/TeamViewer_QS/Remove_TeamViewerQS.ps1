[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false


[String] $TeamViewerQS_Path = "$ENV:PUBLIC\Desktop\TeamViewerQS.exe"

if (!(Test-Path $TeamViewerQS_Path -PathType Leaf))
{
    Write-Output "Team Viewer is already uninstalled"
    exit $ExitWithNoError
}
else
{
    try
    {
        Remove-Item -Path $TeamViewerQS_Path -Force -ErrorAction SilentlyContinue
    }
    catch
    {
        exit $ExitWithError
    }    
}


Write-Output "Team Viewer has been successfully uninstalled"
exit $ExitWithNoError