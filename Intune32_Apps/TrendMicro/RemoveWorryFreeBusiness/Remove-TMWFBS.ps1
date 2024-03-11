param
(
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "TMWFBS_Removal"
)
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

function Start-ScriptLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_LogDirectory = "C:\ProgramData\$($F_CompanyName)IntuneManaged\Logs\$F_ScriptName",
        [String] $F_LogName = "Logs.txt",
        [String] $F_LogPath = "$F_LogDirectory\$F_LogName"
    )
    
    Start-Transcript -Path $F_LogPath -Force -Append
}

Start-ScriptLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName

# Initiating the Uninstall
& ".\SCUT.exe" -noinstall
function IsTrendMicroRunning
{
   if (Get-Service | Where-Object {($_.DisplayName -like "Trend Micro*" -and $_.DisplayName -ne "Trend Micro Cloud Endpoint Telemetry Service") -or $_.DisplayName -like "Worry-Free Business*" -or $_.DisplayName -like "Apex One*"} -ErrorAction SilentlyContinue)
   {
        return $true
   }
   else
   {
        $false
   }

}

[int] $TotalSleepTime = 0
[int] $TotalSleepTimeLimit = 3600
while (IsTrendMicroRunning)
{
    Start-Sleep -Seconds 60
    $TotalSleepTime += 60
    if ($TotalSleepTime -gt $TotalSleepTimeLimit)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}

if (IsTrendMicroRunning)
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}

Stop-Transcript