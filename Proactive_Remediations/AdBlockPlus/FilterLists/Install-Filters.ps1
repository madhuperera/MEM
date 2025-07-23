$RegistryKeysToDetect = 
@{
    "HKLM:\Software\Policies\Google\Chrome\3rdparty\extensions\cfhdojbkjhnklbpkdaibdccddilifddb\policy\additional_subscriptions" = 
    @{
        "1" = "https://easylist-downloads.adblockplus.org/easyprivacy.txt"
        "2" = "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt"
        "3" = "https://cdn.adblockcdn.com/filters/distraction-control-free.txt"
        "4" = "https://easylist-downloads.adblockplus.org/fanboy-social.txt"
        "5" = "https://easylist-downloads.adblockplus.org/fanboy-notifications.txt"
        "6" = "https://easylist-downloads.adblockplus.org/easylist.txt"
        "7" = "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt"
    }
    "HKLM:\Software\Policies\Microsoft\Edge\3rdparty\extensions\gmgoamodcdcjnbaobigkjelfplakmdhh\policy\additional_subscriptions" = 
    @{
        "1" = "https://easylist-downloads.adblockplus.org/easyprivacy.txt"
        "2" = "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt"
        "3" = "https://cdn.adblockcdn.com/filters/distraction-control-free.txt"
        "4" = "https://easylist-downloads.adblockplus.org/fanboy-social.txt"
        "5" = "https://easylist-downloads.adblockplus.org/fanboy-notifications.txt"
        "6" = "https://easylist-downloads.adblockplus.org/easylist.txt"
        "7" = "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt"
    }
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

try 
{
    foreach ($regPath in $RegistryKeysToDetect.Keys) 
    {
        $values = $RegistryKeysToDetect[$regPath]
        foreach ($name in $values.Keys) 
        {
            $data = $values[$name]
            Set-KeyValueData -F_Reg_Key_Path $regPath -F_Reg_Key_Value_Name $name -F_Reg_Key_Value_Data $data -F_Reg_Key_Value_Type "String"
        }
    }
    exit 0
}
catch {
    Write-Error "Failed to set registry keys: $_"
    exit 1
}