[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$SourceAppFolder = "$PSScriptRoot\Images"
$TeamsBackgroundUploads = "$ENV:APPDATA\Microsoft\Teams\Backgrounds\Uploads"

$ImagesToCopy = Get-ChildItem -Path $SourceAppFolder -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

foreach ($Image in $ImagesToCopy)
{
    Copy-Item -Path $Image.
}