param
(
    [String] $S_ScriptName = "RSAT_Detect"
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
    # Check if RSAT (Active Directory DS Tools) is installed
    $rsatCapability = Get-WindowsCapability -Online | Where-Object {$_.Name -eq "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -and $_.State -eq "Installed"}

    if ($null -ne $rsatCapability)
    {
        Write-Output "RSAT is installed."
        exit 0  # Detection successful
    }
    else
    {
        Write-Output "RSAT is not installed."
        exit 1  # Detection failed
    }
}
catch
{
    Write-Output "Error during detection: $_"
    exit 1  # Error occurred
}

Stop-Transcript