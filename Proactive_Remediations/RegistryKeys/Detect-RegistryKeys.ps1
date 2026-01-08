# ---------------------------------------------------------------------------- #
# Functions
# ---------------------------------------------------------------------------- #

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

# ---------------------------------------------------------------------------- #
# Registry Keys to Check - Add your keys here
# ---------------------------------------------------------------------------- #

$RegistryKeys = @(
    @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'EnableActivityFeed'; ValueData = '0'},
    @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'PublishUserActivities'; ValueData = '0'},
    @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; ValueName = 'UploadUserActivities'; ValueData = '0'}
)

# ---------------------------------------------------------------------------- #
# Main Detection Logic
# ---------------------------------------------------------------------------- #

$allCompliant = $true

foreach ($regKey in $RegistryKeys)
{
    $result = Get-KeyValueData -F_Reg_Key_Path $regKey.Path -F_Reg_Key_Value_Name $regKey.ValueName -F_Reg_Key_Value_Data $regKey.ValueData
    
    if (-not $result)
    {
        $allCompliant = $false
        break
    }
}

if ($allCompliant)
{
    Write-Host "All registry keys are compliant"
    exit 0
}
else
{
    Write-Host "One or more registry keys are not compliant"
    exit 1
}
