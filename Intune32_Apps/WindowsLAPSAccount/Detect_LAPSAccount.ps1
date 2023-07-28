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
        [String] $F_LogDirectory = "C:\ProgramData\$($F_CompanyName)IntuneManaged\Logs\$F_ScriptName",
        [String] $F_LogName = "DetectLogs.txt",
        [String] $F_LogPath = "$F_LogDirectory\$F_LogName"
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
        [string] $F_UserName,
        [String] $F_GroupName = "Administrators"
    )

    try
    {
        # Try the Modern PS Cmdlet
        $LMembers = Get-LocalGroupMember -Group $F_GroupName -ErrorAction Stop | Where-Object {$_.Name -like "*\$F_UserName" } 
    }
    catch
    {
        # Reverting to Dos Command to get the Local Group Members
        $LMembers = net localgroup $F_GroupName
        $LMembers = $LMembers | Select-Object -Skip 6
        $LMembers = $LMembers | Where-Object {$_ -like "*$F_UserName*"}
    }

    if ($LMembers)
    {
        return $true
    }
    else 
    {
        return $false
    }

}

$UserAccount = Get-LocalUser $SAccountName -ErrorAction SilentlyContinue
if ($UserAccount)
{
    if (Test-LAPSUserExists -F_UserName $UserAccount)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    else
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
