[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

[String] $SReg_Key_Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
[String] $SReg_Key_Value_Name = "LaunchTo"
[String] $SReg_Key_Value_Data = "1"
[ValidateSet("String","ExpandString","Binary","DWord","MultiString","Qword")] $SReg_Key_Value_Type = "DWord"

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

Function Set-KeyValueData
{
    param
    (
        [string]$F_Reg_Key_Path,
        [string]$F_Reg_Key_Value_Name,
        [string]$F_Reg_Key_Value_Data,
        [string]$F_Reg_Key_Value_Type
    )
    if (!(Test-Path $F_Reg_Key_Path))
    {
        New-Item -Path $F_Reg_Key_Path -Force | Out-Null
    }
    New-ItemProperty -Path $F_Reg_Key_Path -Name $F_Reg_Key_Value_Name -Value $F_Reg_Key_Value_Data -PropertyType $F_Reg_Key_Value_Type -Force | Out-Null
}

try
{
    Set-KeyValueData -F_Reg_Key_Path $SReg_Key_Path -F_Reg_Key_Value_Name $SReg_Key_Value_Name -F_Reg_Key_Value_Data $SReg_Key_Value_Data -$SReg_Key_Value_Type
    SUCCESS --> Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
catch
{
    FAILURE --> Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
