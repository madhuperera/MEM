[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
[String] $SReg_Key_Parent_Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection"
[String] $SReg_Key_Name = "DeviceTagging"
[String] $SReg_Key_Value_Name = "Group"
[String] $SReg_Key_Value_Data = "New_Zealand"

function Test-RegistryKeyValue
{
    param
    (
        [String] $F_Reg_Key_Parent_Path,
        [String] $F_Reg_Key_Name,
        [String] $F_Reg_Key_Value_Name,
        [String] $F_Reg_Key_Value_Data
        # [ValidateSet("String","ExpandString","Binary","DWord","MultiString","Qword")] $F_Reg_Key_Value_Type
    )

    [bool] $ExitValue = $false

    if(Test-Path -Path "$F_Reg_Key_Parent_Path\$Reg_Key_Name" -PathType Container)
    {
        if (Get-ItemProperty -Path "$F_Reg_Key_Parent_Path\$F_Reg_Key_Name" -Name $F_Reg_Key_Value_Name)
        {
            if ((Get-ItemPropertyValue -Path "$F_Reg_Key_Parent_Path\$F_Reg_Key_Name" -Name $F_Reg_Key_Value_Name) -eq $F_Reg_Key_Value_Data)
            {
                $ExitValue = $true
            }
        }
    }

    return $ExitValue
}

if (Test-RegistryKeyValue -F_Reg_Key_Parent_Path $SReg_Key_Parent_Path -F_Reg_Key_Name $SReg_Key_Name -F_Reg_Key_Value_Name $SReg_Key_Value_Name -F_Reg_Key_Value_Data $SReg_Key_Value_Data)
{
    exit $ExitWithNoError
}
else
{
    exit $ExitWithError
}