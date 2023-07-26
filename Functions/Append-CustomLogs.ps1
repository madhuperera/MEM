param
(
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "TestName"
)
function Update-CustomLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_Message,        
        [String] $F_LogDirectory = "C:\ProgramData\$($CompanyName)IntuneManaged\Logs\$ScriptName",
        [String] $F_CustomLogName = "CustomLogs.txt",
        [String] $F_CustomLogPath = "$LogDirectory\$CustomLogName"
    )
    
    [String] $TimeStamp = Get-Date -Format "yyyy-MM-dd-HH:mm:ss__"

    [String] $LogEntry = $TimeStamp + $F_Message
    $LogEntry | Out-File -FilePath $F_CustomLogPath -Append -Force -ErrorAction SilentlyContinue
}

Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "Starting Custom Log"