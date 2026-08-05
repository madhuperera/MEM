$RegistryChecks = 
@{
    "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown" = 
    @{
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
}

$removedValues = @()

foreach ($regPath in $RegistryChecks.Keys) {
    if (-not (Test-Path -Path $regPath)) {
        continue
    }

    foreach ($valueName in $RegistryChecks[$regPath].Keys) {
        $expectedData = $RegistryChecks[$regPath][$valueName].Data

        try {
            $currentValue = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction Stop).$valueName
        } catch {
            continue
        }

        if ($currentValue -eq $expectedData) {
            try {
                Remove-ItemProperty -Path $regPath -Name $valueName -ErrorAction Stop
                $removedValues += "$regPath\\$valueName"
            } catch {
                Write-Output "Failed to remove registry value: $regPath\\$valueName"
            }
        }
    }
}

if ($removedValues.Count -gt 0) {
    Write-Output "Removed registry values: $($removedValues -join ', ')"
} else {
    Write-Output "No matching registry values found to remove."
}

exit 0
