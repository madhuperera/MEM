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
    $allSuccess = $true
    foreach ($Key in $S_Reg_Key_ValuePair)
    {
        $RegKeyPath = $Key.KeyPath
        $RegKeyName = $Key.ValueName

        try
        {
            Remove-KeyValueName -F_Reg_Key_Path $RegKeyPath -F_Reg_Key_Value_Name $RegKeyName
            Write-Output "Successfully removed the Registry Key value: $($RegKeyPath)$($RegKeyName)"
        }
        catch
        {
            Write-Output "Failed to remove the Registry Key value: $($RegKeyPath)$($RegKeyName)"
            $allSuccess = $false
        }
    }
    if ($allSuccess)
    {
        exit 0
    }
    else
    {
        exit 1
    }
}

main