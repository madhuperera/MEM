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

$matchFound = $false

foreach ($regPath in $RegistryChecks.Keys) {
    if (-not (Test-Path -Path $regPath)) {
        continue
    }

    $regProps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if ($null -eq $regProps) {
        continue
    }

    foreach ($valueName in $RegistryChecks[$regPath].Keys) {
        $expectedData = $RegistryChecks[$regPath][$valueName].Data

        if ($regProps.PSObject.Properties.Name -notcontains $valueName) {
            continue
        }

        $currentValue = $regProps.$valueName

        if ([int]$currentValue -eq [int]$expectedData) {
            $matchFound = $true
            break
        }
    }

    if ($matchFound) {
        break
    }
}

if ($matchFound) {
    Write-Output "Registry values found"
    exit 1
}

Write-Output "No registry values found"
exit 0

