[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$PreferredSystemLocale = "en-NZ"
$CurrentSystemLocale = (Get-WinSystemLocale).Name

if ($CurrentSystemLocale -eq $PreferredSystemLocale)
{
    Write-Output "No changes needed"
    exit $ExitWithNoError
}
else
{
    try
    {
        Set-WinSystemLocale -SystemLocale "en-NZ"
        Write-Output "Setting has been updated"
        exit $ExitWithNoError
    }
    catch
    {
        Write-Output "Error updating the System Locale Settings."
        exit $ExitWithError
    }
}