If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}

param
    (
        [String] $SReg_Key_Parent_Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection",
        [String] $SReg_Key_Name = "DeviceTagging",
        [String] $SReg_Key_Value_Name = "Group",
        [String] $SReg_Key_Value_Data = "New_Zealand",
        [ValidateSet("String","ExpandString","Binary","DWord","MultiString","Qword")] $SReg_Key_Value_Type = "String"
    )

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
    [bool] $ExitWithError = $true
    [bool] $ExitWithNoError = $false

    if(!(Test-Path -Path "$Reg_Key_Parent_Path\$Reg_Key_Name" -PathType Container))
    {
        New-Item -Path $Reg_Key_Parent_Path -Name $Reg_Key_Name -ItemType Conatiner -Force
    }

    if ($Reg_Key_Value_Data -and $Reg_Key_Value_Name)
    {
        try
        {
            New-ItemProperty -Path "$Reg_Key_Parent_Path\$Reg_Key_Name" -Name $Reg_Key_Value_Name -PropertyType $Reg_Key_Value_Type -Value $Reg_Key_Value_Data -Force
        }
        catch
        {
            exit $ExitWithError
        }
        
    }
    exit $ExitWithNoError
}

Update-RegistryKey -Reg_Key_Parent_Path $SReg_Key_Parent_Path -Reg_Key_Name $SReg_Key_Name -Reg_Key_Value_Name $SReg_Key_Value_Name -Reg_Key_Value_Data $SReg_Key_Value_Data -Reg_Key_Value_Type $SReg_Key_Value_Type