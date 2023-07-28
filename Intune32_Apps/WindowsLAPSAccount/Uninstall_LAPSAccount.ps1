param
(
    [String] $SAccountName = "LocalAccountName",
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "LAPS"
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

function Start-ScriptLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_LogDirectory = "C:\ProgramData\$($CompanyName)IntuneManaged\Logs\$ScriptName",
        [String] $F_LogName = "Logs.txt",
        [String] $F_LogPath = "$LogDirectory\$LogName"
    )
    
    Start-Transcript -Path $F_LogPath -Force -Append
}

Start-ScriptLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName
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
        Stop-Transcript
        exit 1
    }
    else
    {
        Stop-Transcript
        exit 0
    }
}

function Test-LAPSUserExists
{
    param 
    (
        [String] $F_UserName
    )

    try
    {
        $UserAccount = Get-LocalUser $F_UserName -ErrorAction Stop
    }
    catch
    {
        $Results = net user $F_UserName
        $Results = $Results | Where-Object {$_ -like "*$F_UserName*The command completed successfully*"}
    }

    if ($UserAccount -or $Results)
    {
        return $true
    }
    else 
    {
        return $false
    }
}



if (Test-LAPSUserExists -F_UserName $SAccountName)
{
    try
    {
        Remove-LocalUser -Name $SAccountName -Confirm:$false -ErrorAction Stop
    }
    catch
    {
        net user $SAccountName /delete
    }

    if (Test-LAPSUserExists -F_UserName $SAccountName)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "ERROR"
    }
    else
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
