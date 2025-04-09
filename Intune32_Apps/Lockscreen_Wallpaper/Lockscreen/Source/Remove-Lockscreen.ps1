$S_Reg_Key_ValuePair = @(
    @{
        KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImagePath"
        ValueData = "C:\Windows\Web\Screen\VO_Lockscreen.png"
    },
    @{
        KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImageStatus"
        ValueData = 1
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

# Scenario 3: Delete the key value name
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

function main
{
    foreach ($Key in $S_Reg_Key_ValuePair)
    {
        $RegKeyPath = $Key.KeyPath
        $RegKeyName = $Key.ValueName
        $RegKeyValue = $Key.ValueData

        # Check if the registry key exists and if the value matches the expected data
        if (Get-KeyValueData -F_Reg_Key_Path $RegKeyPath -F_Reg_Key_Value_Name $RegKeyName -F_Reg_Key_Value_Data $RegKeyValue)
        {
            try
            {
                Remove-KeyValueName -F_Reg_Key_Path $RegKeyPath -F_Reg_Key_Value_Name $RegKeyName
                Write-Host "Successfully removed the Registry Key value: $RegKeyPath\$RegKeyName = $RegKeyValue"
                exit 0
            }
            catch
            {
                Write-Host "Failed to remove the Registry Key value: $RegKeyPath\$RegKeyName = $RegKeyValue"
                exit 1
            }
        }
        else
        {
            Write-Host "Registry key value does not exist: $RegKeyPath\$RegKeyName = $RegKeyValue"
            exit 0
        }
    }
} 

main