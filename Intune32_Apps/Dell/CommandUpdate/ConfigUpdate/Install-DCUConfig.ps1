param
    (
        [String] $SReg_Key_Parent_Path = "HKLM:\SOFTWARE\IntuneManagedApps",
        [String] $SReg_Key_Name = "DellCommandConfig",
        [String] $SReg_Key_Value_Name = "Version",
        [String] $SReg_Key_Value_Data = "2023.07.11",
        [ValidateSet("String","ExpandString","Binary","DWord","MultiString","Qword")] $SReg_Key_Value_Type = "String"
    )

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
function Update-RegistryKey
{
    param
    (
        [String] $Reg_Key_Parent_Path,
        [String] $Reg_Key_Name,
        [String] $Reg_Key_Value_Name,
        [String] $Reg_Key_Value_Data,
        [ValidateSet("String","ExpandString","Binary","DWord","MultiString","Qword")] $Reg_Key_Value_Type
    )

    if(!(Test-Path -Path "$Reg_Key_Parent_Path\$Reg_Key_Name" -PathType Container))
    {
        New-Item -Path $Reg_Key_Parent_Path -Name $Reg_Key_Name -ItemType Conatiner -Force | Out-Null
    }

    if ($Reg_Key_Value_Data -and $Reg_Key_Value_Name)
    {
        try
        {
            New-ItemProperty -Path "$Reg_Key_Parent_Path\$Reg_Key_Name" -Name $Reg_Key_Value_Name -PropertyType $SReg_Key_Value_Type -Value $Reg_Key_Value_Data -Force | Out-Null
        }
        catch
        {
            return $false
        }
        
    }
    return $true
}

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


."C:\Program Files\Dell\CommandUpdate\dcu-cli.exe" /configure -importSettings=".\Settings.xml" -outputLog=".\RunningDellLog.log"
$LogFileContent = Get-Content -Path ".\RunningDellLog.log" -ErrorAction SilentlyContinue
if ($LogFileContent | Where-Object {$_ -like "*The program exited with return code: 0*"})
{
    if (Update-RegistryKey -Reg_Key_Parent_Path $SReg_Key_Parent_Path -Reg_Key_Name $SReg_Key_Name -Reg_Key_Value_Name $SReg_Key_Value_Name -Reg_Key_Value_Data $SReg_Key_Value_Data -Reg_Key_Value_Type $SReg_Key_Value_Type)
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

