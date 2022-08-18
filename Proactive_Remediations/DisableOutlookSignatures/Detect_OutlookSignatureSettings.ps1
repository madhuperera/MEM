[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

# Microsoft Office 365 and Outlook 2016
[String] $SReg_Key_Parent_Path = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common"
[String] $SReg_Key_Name = "MailSettings"
[String] $SReg_Key_Value_Name = "DisableSignatures"
[String] $SReg_Key_Value_Data = "1"


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

try
{
  [bool] $KeyDataStatus = Test-RegistryKeyValue -F_Reg_Key_Parent_Path $SReg_Key_Parent_Path -F_Reg_Key_Name $SReg_Key_Name -F_Reg_Key_Value_Name $SReg_Key_Value_Name -F_Reg_Key_Value_Data $SReg_Key_Value_Data
  if ($KeyDataStatus)
  {
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
  }
  else
  {
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
  }
}
catch
{
  Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
