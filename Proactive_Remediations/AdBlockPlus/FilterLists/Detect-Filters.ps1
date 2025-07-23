# Hashtable of registry keys to detect
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

$missingEntries = @()

foreach ($regPath in $RegistryKeysToDetect.Keys) 
{
    foreach ($valueName in $RegistryKeysToDetect[$regPath].Keys) 
    {
        $valueData = $RegistryKeysToDetect[$regPath][$valueName]
        if (-not (Get-KeyValueData -F_Reg_Key_Path $regPath -F_Reg_Key_Value_Name $valueName -F_Reg_Key_Value_Data $valueData)) 
        {
            $missingEntries += "$regPath\$valueName = $valueData"
        }
    }
}

if ($missingEntries.Count -gt 0) 
{
    Write-Error "Missing registry entries:`n$($missingEntries -join "`n")"
    exit 1
}