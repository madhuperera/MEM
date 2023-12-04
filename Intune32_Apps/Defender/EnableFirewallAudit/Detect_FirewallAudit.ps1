param
(
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "FirewallAuditDetect"
)

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

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

function Update-CustomLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_Message,        
        [String] $F_LogDirectory = "C:\ProgramData\$($F_CompanyName)IntuneManaged\Logs\$F_ScriptName",
        [String] $F_CustomLogName = "CustomLogs.txt",
        [String] $F_CustomLogPath = "$F_LogDirectory\$F_CustomLogName"
    )
    
    [String] $TimeStamp = Get-Date -Format "yyyy-MM-dd-HH:mm:ss__"

    [String] $LogEntry = $TimeStamp + $F_Message
    $LogEntry | Out-File -FilePath $F_CustomLogPath -Append -Force -ErrorAction SilentlyContinue
}

Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "Starting Custom Log"


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

try
{

    $categories = "Filtering Platform Packet Drop,Filtering Platform Connection"
    $current = auditpol /get /subcategory:"$($categories)" /r | ConvertFrom-Csv    
    if ($current."Inclusion Setting" -ne "failure")
    {
        Write-Host "Remediation Needed. $($current | ForEach-Object {$_.Subcategory + ":" + $_.'Inclusion Setting' + ";"})."
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
    else
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }

}
catch
{
    throw $_
} 



# FAILURE --> Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
# SUCCESS --> Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"