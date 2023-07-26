param
(
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "TestName"
)

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