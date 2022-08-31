[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
[String] $S_Reg_Key_Parent_Path = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
[String] $S_Reg_Key_Name = "Windows"
[String] $S_Reg_Key_Value_Name = "LegacyDefaultPrinterMode"
[String] $S_Reg_Key_Value_Data = "1"
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

if (Test-RegistryKeyValue -F_Reg_Key_Parent_Path $S_Reg_Key_Parent_Path -F_Reg_Key_Name $S_Reg_Key_Name -F_Reg_Key_Value_Name $S_Reg_Key_Value_Name -F_Reg_Key_Value_Data $S_Reg_Key_Value_Data)
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}