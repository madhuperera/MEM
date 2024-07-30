[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

[String] $SReg_Key_Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
[String] $SReg_Key_Value_Name = "LaunchTo"

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

Function Remove-KeyValueName
{
    param
    (
        [string]$F_Reg_Key_Path,
        [string]$F_Reg_Key_Value_Name
    )
    if (Test-Path $F_Reg_Key_Path)
    {
        Remove-ItemProperty -Path $F_Reg_Key_Path -Name $F_Reg_Key_Value_Name
    }
}

try
{
    Remove-KeyValueName -F_Reg_Key_Path $SReg_Key_Path -F_Reg_Key_Value_Name $SReg_Key_Value_Name
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
catch
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
