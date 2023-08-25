param
(
    [string] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "UpdateIETrustedSites",
    [bool] $ExitWithError = $true,
    [bool] $ExitWithNoError = $false,
    [String] $SReg_Key_Parent_Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains",
    [String] $SReg_Key_Name = "yourtrustedsite.com",
    [String] $SReg_Key_Value_Name = "https",
    [String] $SReg_Key_Value_Data = 2,
    [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "Qword")] $SReg_Key_Value_Type = "DWord"
)

If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64")
{
    Try
    {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch
    {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
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

function Update-RegistryKey
{
    param
    (
        [String] $F_Reg_Key_Parent_Path,
        [String] $F_Reg_Key_Name,
        [String] $F_Reg_Key_Value_Name,
        [String] $F_Reg_Key_Value_Data,
        [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "Qword")] $F_Reg_Key_Value_Type
    )

    if (!(Test-Path -Path "$F_Reg_Key_Parent_Path\$F_Reg_Key_Name" -PathType Container))
    {
        New-Item -Path $F_Reg_Key_Parent_Path -Name $F_Reg_Key_Name -ItemType Conatiner -Force -Verbose | Out-Null
    }

    if ($F_Reg_Key_Value_Data -and $F_Reg_Key_Value_Name)
    {
        try
        {
            New-ItemProperty -Path "$F_Reg_Key_Parent_Path\$F_Reg_Key_Name" -Name $F_Reg_Key_Value_Name -PropertyType $F_Reg_Key_Value_Type -Value $F_Reg_Key_Value_Data -Force -Verbose | Out-Null
        }
        catch
        {
            return $false
        }
        
    }
    return $true
}

if (Update-RegistryKey -F_Reg_Key_Parent_Path $SReg_Key_Parent_Path -F_Reg_Key_Name $SReg_Key_Name -F_Reg_Key_Value_Name $SReg_Key_Value_Name -F_Reg_Key_Value_Data $SReg_Key_Value_Data -F_Reg_Key_Value_Type $SReg_Key_Value_Type)
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
