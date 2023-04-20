[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
[bool] $SPasswordNeverExpires = $true
[bool] $SUserMayChangePassword = $false
[String] $SAccountName = "LocalAccountName" # Please change

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

$UserAccount = Get-LocalUser $SAccountName -ErrorAction SilentlyContinue
if ($UserAccount)
{
    if (!$UserAccount.UserMayChangePassword)
    {
        Set-LocalUser $SAccountName -PasswordNeverExpires $SPasswordNeverExpires -UserMayChangePassword $SUserMayChangePassword
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    else
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}