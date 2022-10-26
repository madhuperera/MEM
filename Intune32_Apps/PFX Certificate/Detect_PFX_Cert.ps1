# PLEASE CHANGE SETTINGS BELOW
[String] $S_Cert_FriendlyName = ""       
[int] $S_ExpiryWindowInDays = 7
[String] $S_Cert_Location = "Cert:\CurrentUser\My\"


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

try
{
    $AllPersonalCerts = Get-ChildItem -Path $S_Cert_Location -ErrorAction SilentlyContinue
    $UpdateBefore = (Get-Date).AddDays($S_ExpiryWindowInDays)
    foreach ($Cert in $AllPersonalCerts)
    {
        if (($Cert.FriendlyName -eq $S_Cert_FriendlyName) -and ($Cert.NotAfter -gt $UpdateBefore))
        {
            Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
        }
    }
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
catch
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
