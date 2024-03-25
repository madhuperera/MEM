If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}


[String] $SReg_Key_Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging"
[String] $SReg_Key_Value_Name = "Group"
[String] $SReg_Key_Value_Data = "New_Zealand"
[ValidateSet("String","ExpandString","Binary","DWord","MultiString","Qword")] $SReg_Key_Value_Type = "String"
[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
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

Function Get-KeyValueData
{
    param
    (
        [string]$F_Reg_Key_Path,
        [string]$F_Reg_Key_Value_Name,
        [string]$F_Reg_Key_Value_Data
    )

    $key = Get-Item -Path $F_Reg_Key_Path -ErrorAction SilentlyContinue
    if ($key -ne $null)
    {
        $value = $key.GetValue($F_Reg_Key_Value_Name)
        if ($value -eq $F_Reg_Key_Value_Data)
        {
            return $true
        }
    }
    return $false
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

Set-KeyValueData -F_Reg_Key_Path $SReg_Key_Path -F_Reg_Key_Value_Name $SReg_Key_Value_Name -F_Reg_Key_Value_Data $SReg_Key_Value_Data -F_Reg_Key_Value_Type $SReg_Key_Value_Type

if (Get-KeyValueData -F_Reg_Key_Path $SReg_Key_Path -F_Reg_Key_Value_Name $SReg_Key_Value_Name -F_Reg_Key_Value_Data $SReg_Key_Value_Data)
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}