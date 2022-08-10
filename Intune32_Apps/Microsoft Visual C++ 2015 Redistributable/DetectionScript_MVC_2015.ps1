function Update-OutputOnExit
{
    param
    (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode)
    {
        exit 1
    }
    else
    {
        exit 0
    }
}

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

$Win32App_Name = "Microsoft Visual C++ 201* x64 Minimum Runtime - *"

if (Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object {$_.Name -like "$($Win32App_Name)"})
{
    Write-Output "$Win32App_Name is already installed"
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Write-Output "$Win32App_Name is not installed"
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}