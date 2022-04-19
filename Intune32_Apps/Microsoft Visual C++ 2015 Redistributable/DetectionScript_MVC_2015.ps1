[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$Win32App_Name = "Microsoft Visual C++ 2015 x64 Minimum Runtime - 14.0.24215"

if (Get-WmiObject -Class Win32_Product -Filter "Name = `'$($Win32App_Name)`'" -ErrorAction SilentlyContinue)
{
    Write-Output "$Win32App_Name is already installed"
    exit $ExitWithNoError
}
else
{
    Write-Output "$Win32App_Name is not installed"
    exit $ExitWithError
}