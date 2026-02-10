# ---------------------------------------------------------------------------- #
# Functions
# ---------------------------------------------------------------------------- #

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

# ---------------------------------------------------------------------------- #
# Registry Keys to Set - Must match Detect script
# ---------------------------------------------------------------------------- #

$RegistryKeys = @(
    @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'EnableActivityFeed'; ValueData = '0'; ValueType = 'DWord'},
    @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'PublishUserActivities'; ValueData = '0'; ValueType = 'DWord'},
    @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'UploadUserActivities'; ValueData = '0'; ValueType = 'DWord'}
)

# ---------------------------------------------------------------------------- #
# Main Remediation Logic
# ---------------------------------------------------------------------------- #

foreach ($regKey in $RegistryKeys)
{
    Set-KeyValueData -F_Reg_Key_Path $regKey.Path -F_Reg_Key_Value_Name $regKey.ValueName -F_Reg_Key_Value_Data $regKey.ValueData -F_Reg_Key_Value_Type $regKey.ValueType
}

Write-Host "Registry keys remediated"
exit 0
