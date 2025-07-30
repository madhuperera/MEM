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
    foreach ($regPath in $RegistryChecks.Keys) 
    {
        foreach ($valueName in $RegistryChecks[$regPath].Keys) 
        {
            $valueProps = $RegistryChecks[$regPath][$valueName]
            Set-KeyValueData -F_Reg_Key_Path $regPath `
                             -F_Reg_Key_Value_Name $valueName `
                             -F_Reg_Key_Value_Data $valueProps.Data `
                             -F_Reg_Key_Value_Type $valueProps.Type
        }
    }
    Write-Output "Registry settings applied successfully."
    exit 0
} 
catch 
{
    Write-Output "Failed to apply registry settings: $_"
    exit 1
}