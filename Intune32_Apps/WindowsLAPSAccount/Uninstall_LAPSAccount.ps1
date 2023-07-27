param
(
    [String] $SAccountName = "LocalAccountName"
)

If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

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

    try
    {
        Remove-LocalUser -Name $SAccountName -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
