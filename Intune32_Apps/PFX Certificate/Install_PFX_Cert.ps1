# PLEASE CHANGE SETTINGS BELOW
# DISCLAIMER: It is not recommended use your password within Scripts! So continue at your own risk.
[String] $S_Cert_Name = ""       
[String] $S_Cert_Password = ""


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

[String] $Results = certutil -f -user -p $S_Cert_Password -importpfx ".\$S_Cert_Name"

if ($Results -like "*importPFX command completed successfully*")
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}