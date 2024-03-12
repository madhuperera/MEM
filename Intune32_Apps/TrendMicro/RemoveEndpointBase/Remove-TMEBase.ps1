param
(
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "TMEBase_Removal"
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
# XBCUninstaller.exe XBCUninstallToken.txt
Start-Process -FilePath 'XBCUninstaller.exe' -ArgumentList 'XBCUninstallToken.txt' -Verb RunAs

function IsTrendMicroRunning
{
   if (Get-Service | Where-Object {$_.DisplayName -eq "Trend Micro Cloud Endpoint Telemetry Service" -or $_.DisplayName -eq "Trend Micro Endpoint Basecamp" -or $_.DisplayName -eq "Trend Micro Web Service Communicator"} -ErrorAction SilentlyContinue)
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