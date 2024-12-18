param
(
    [String] $S_ScriptName = "RSAT_Install"
)
function Start-ScriptLogs
{
    param
    (
        [String] $F_ScriptName,
        [String] $F_LogDirectory = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$F_ScriptName",
        [String] $F_LogName = "Logs.txt",
        [String] $F_LogPath = "$F_LogDirectory\$F_LogName"
    )
    
    if (-not (Test-Path -Path $F_LogDirectory))
    {
        New-Item -ItemType Directory -Path $F_LogDirectory -Force | Out-Null
    }
    
    Start-Transcript -Path $F_LogPath -Force -Append
}

Start-ScriptLogs -F_ScriptName $S_ScriptName

try
{
    # Install RSAT (Active Directory DS Tools)
    Write-Output "Starting RSAT installation..."
    Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -ErrorAction Stop
    Write-Output "RSAT installation completed successfully."
    exit 0  # Installation successful
}
catch
{
    Write-Output "Error during installation: $_"
    exit 1  # Installation failed
}

Stop-Transcript
