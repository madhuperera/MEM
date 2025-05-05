param
(
    [string]$ClientName = "Sonitlo"
)

$S_Reg_Key_ValuePair = @(
    @{
        KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImagePath"
        ValueData = "C:\Windows\Web\Screen\$($ClientName)_Lockscreen.png"
        ValueType = "String"
    },
    @{
        KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImageStatus"
        ValueData = 1
        ValueType = "DWord"
    }
)

# Scenario 1: Detect the key value data
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

# Scenario 2: Create or update the key value data
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

function main
{
    foreach ($Key in $S_Reg_Key_ValuePair)
    {
        $RegKeyPath = $Key.KeyPath
        $RegKeyName = $Key.ValueName
        $RegKeyValue = $Key.ValueData
        $RegKeyType = $Key.ValueType

        if (Get-KeyValueData -F_Reg_Key_Path $RegKeyPath -F_Reg_Key_Value_Name $RegKeyName -F_Reg_Key_Value_Data $RegKeyValue)
        {
            Write-Host "Registry key value exists: $RegKeyPath\$RegKeyName = $RegKeyValue"
            exit 0
        }
        else
        {
            try
            {
                Set-KeyValueData -F_Reg_Key_Path $RegKeyPath -F_Reg_Key_Value_Name $RegKeyName -F_Reg_Key_Value_Data $RegKeyValue -F_Reg_Key_Value_Type $RegKeyType
                Write-Host "Successfully updated registry key value: $RegKeyPath\$RegKeyName = $RegKeyValue"
                exit 0
            }
            catch
            {
                Write-Host "Failed to set registry key value: $RegKeyPath\$RegKeyName = $RegKeyValue"
                exit 1
            }          
            
        }
    }
}

main