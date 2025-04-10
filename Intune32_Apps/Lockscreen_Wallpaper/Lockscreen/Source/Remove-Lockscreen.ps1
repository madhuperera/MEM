$S_Reg_Key_ValuePair = @(
    @{
        KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImagePath"
    },
    @{
        KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImageStatus"
    }
)

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

       
        try
        {
            Remove-KeyValueName -F_Reg_Key_Path $RegKeyPath -F_Reg_Key_Value_Name $RegKeyName
            Write-Host "Successfully removed the Registry Key value: $($RegKeyPath)$($RegKeyName)"
            exit 0
        }
        catch
        {
            Write-Host "Failed to remove the Registry Key value: $($RegKeyPath)$($RegKeyName)"
            exit 1
        }
    }
} 

main