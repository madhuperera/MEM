$S_Reg_Key_Path = "HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Options"
$S_Reg_Key_Value_Name = "defaultformat"
$S_Reg_Key_Value_Data = 51 # 51 = Excel Workbook (XLSX)
$S_Reg_Key_Value_Type = "DWORD"

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

function Main
{
    if (Get-KeyValueData -F_Reg_Key_Path $S_Reg_Key_Path -F_Reg_Key_Value_Name $S_Reg_Key_Value_Name -F_Reg_Key_Value_Data $S_Reg_Key_Value_Data)
    {
        Write-Output "SUCCESS: $($S_Reg_Key_Path)\$($S_Reg_Key_Value_Name) is set to $($S_Reg_Key_Value_Data)."
        exit 0
    }
    else
    {
        Write-Output "The registry key value is not set to the required value."
        exit 1
    }
}

Main