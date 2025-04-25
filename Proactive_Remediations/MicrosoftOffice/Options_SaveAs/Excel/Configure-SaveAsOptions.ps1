$S_Reg_Key_Path = "HKCU:\Software\Microsoft\Office\16.0\Excel\Options"
$S_Reg_Key_Value_Name = "defaultformat"
$S_Reg_Key_Value_Data = 51 # 51 = Excel Workbook (XLSX)
$S_Reg_Key_Value_Type = "DWORD"

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
    Set-KeyValueData -F_Reg_Key_Path $S_Reg_Key_Path -F_Reg_Key_Value_Name $S_Reg_Key_Value_Name -F_Reg_Key_Value_Data $S_Reg_Key_Value_Data -F_Reg_Key_Value_Type $S_Reg_Key_Value_Type
    Write-Output "SUCCESS: $($S_Reg_Key_Path)\$($S_Reg_Key_Value_Name) is set to $($S_Reg_Key_Value_Data)."
    exit 0
}
catch
{
    Write-Output "ERROR: Failed to set $($S_Reg_Key_Path)\$($S_Reg_Key_Value_Name) to $($S_Reg_Key_Value_Data)."
    exit 1 
}

