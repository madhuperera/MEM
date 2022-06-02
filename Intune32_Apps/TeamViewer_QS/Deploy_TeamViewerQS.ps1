[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$SourceAppFolder = "$PSScriptRoot"
$PublicDesktopFolder = "$ENV:PUBLIC\Desktop"

if (!(Test-Path $SourceAppFolder -PathType Container))
{
    Write-Output "Source App folder is not located at $SourceAppFolder"
    exit $ExitWithError
}
else
{
    Write-Output "Source App folder is found"
    try
    {
        Copy-Item -Path "$SourceAppFolder\TeamViewerQS.exe" -Destination $PublicDesktopFolder -Force -ErrorAction SilentlyContinue
    }
    catch
    {
        exit $ExitWithError
    }    
}


Write-Output "All Apps have been successfully installed and updated"
exit $ExitWithNoError