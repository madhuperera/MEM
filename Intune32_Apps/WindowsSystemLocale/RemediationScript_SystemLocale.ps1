[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$PreferredSystemLocale = "en-NZ"
$CurrentSystemLocale = (Get-WinSystemLocale).Name

if ($CurrentSystemLocale -eq $PreferredSystemLocale)
{
    Write-Output "No changes needed"
    exit $ExitWithNoError
}
}
else
{
    Set-WinSystemLocale -SystemLocale "en-NZ"
    Write-Output "Setting has been updated"
    exit $ExitWithNoError
}