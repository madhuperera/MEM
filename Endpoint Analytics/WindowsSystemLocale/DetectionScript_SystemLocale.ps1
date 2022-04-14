[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$PreferredSystemLocale = "en-NZ"
$CurrentSystemLocale = (Get-WinSystemLocale).Name

if ($CurrentSystemLocale -eq $PreferredSystemLocale)
{
    Write-Output "Preferred Setting has already been applied"
    exit $ExitWithNoError
}
}
else
{
    Write-Output "Current Setting does not match preferred setting"
    exit $ExitWithError
}