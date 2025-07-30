# Detect-AdobeSettings.ps1
# Intune Proactive Remediation Detection Script for Adobe Acrobat Hardening

# Define registry keys, value names, expected types, and expected data
$RegistryChecks = 
@{
    "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown" = 
    @{
        "bDisableJavaScript" = 
        @{
            Type = "DWord"
            Data = 1
        }
        "bEnhancedSecurityStandalone" = 
        @{
            Type = "DWord"
            Data = 1
        }
        "bEnhancedSecurityInBrowser" = 
        @{
            Type = "DWord"
            Data = 1
        }
        "bProtectedMode" = 
        @{
            Type = "DWord"
            Data = 1
        }
        "iProtectedView" = 
        @{
            Type = "DWord"
            Data = 2
        }
        "bEnableProtectedModeAppContainer" = 
        @{
            Type = "DWord"
            Data = 1
        }
    }
    "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\Privileged" = 
    @{
        "bDisableTrustedFolders" = 
        @{
            Type = "DWord"
            Data = 1
        }
    }
}

$Compliant = $true
$ErrorMessages = @()

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

foreach ($RegPath in $RegistryChecks.Keys)
{
    $KeyExists = Test-Path $RegPath
    if (-not $KeyExists)
    {
        Write-Output "Compliant: Adobe Acrobat is possibly not installed. Registry key '$RegPath' does not exist."
        exit 0
    }
    foreach ($ValueName in $RegistryChecks[$RegPath].Keys)
    {
        $Expected = $RegistryChecks[$RegPath][$ValueName]
        $Result = Get-KeyValueData -F_Reg_Key_Path $RegPath -F_Reg_Key_Value_Name $ValueName -F_Reg_Key_Value_Data $Expected.Data
        if (-not $Result)
        {
            $Compliant = $false
            $ErrorMessages += "Incorrect or missing value '$ValueName' in '$RegPath'. Expected: $($Expected.Data)"
        }
    }
}

if ($Compliant) 
{
    Write-Output "Compliant: All Adobe Acrobat settings are correct."
    exit 0
} 
else 
{
    Write-Output "Non-Compliant: " + ($ErrorMessages -join "; ")
    exit 1
}