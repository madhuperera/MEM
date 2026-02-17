<#
.SYNOPSIS
    Detects CrowdStrike Falcon Sensor installation for Intune app detection.

.DESCRIPTION
    This script checks for the presence of CrowdStrike Falcon Sensor on a Windows device.
    It verifies installation by checking registry keys and installation paths.
    Designed for use as an Intune Win32 app detection custom script.

.NOTES
    File Name      : Detect-FalconSensor.ps1
    Author         : Madhu Perera
    Prerequisite   : PowerShell 5.1 or later
    
.EXAMPLE
    .\Detect-FalconSensor.ps1
    
.OUTPUTS
    Exit Code 0: CrowdStrike Falcon Sensor is installed
    Exit Code 1: CrowdStrike Falcon Sensor is not installed
#>

[CmdletBinding()]
param()

try {
    # Define registry paths to check for CrowdStrike Falcon Sensor
    $registryPaths = @(
        "HKLM:\SOFTWARE\CrowdStrike\{9081BF4D-0A18-435A-A819-16D406F7E1ED}",
        "HKLM:\SOFTWARE\WOW6432Node\CrowdStrike\{9081BF4D-0A18-435A-A819-16D406F7E1ED}",
        "HKLM:\SYSTEM\CurrentControlSet\Services\CSAgent",
        "HKLM:\SYSTEM\CurrentControlSet\Services\CSFalconService"
    )
    
    # Define common installation paths
    $installPaths = @(
        "$env:ProgramFiles\CrowdStrike\CSFalconService.exe",
        "${env:ProgramFiles(x86)}\CrowdStrike\CSFalconService.exe",
        "$env:SystemRoot\System32\drivers\CrowdStrike\*.sys"
    )
    
    $sensorFound = $false
    
    # Check registry paths
    foreach ($regPath in $registryPaths) {
        if (Test-Path -Path $regPath -ErrorAction SilentlyContinue) {
            $sensorFound = $true
            Write-Output "CrowdStrike Falcon Sensor detected in registry: $regPath"
            break
        }
    }
    
    # If not found in registry, check installation paths
    if (-not $sensorFound) {
        foreach ($path in $installPaths) {
            if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
                $sensorFound = $true
                Write-Output "CrowdStrike Falcon Sensor detected at: $path"
                break
            }
        }
    }
    
    # Check for CSFalconService service
    if (-not $sensorFound) {
        $service = Get-Service -Name "CSFalconService" -ErrorAction SilentlyContinue
        if ($service) {
            $sensorFound = $true
            Write-Output "CrowdStrike Falcon Sensor service detected: CSFalconService"
        }
    }
    
    # Return result
    if ($sensorFound) {
        Write-Output "CrowdStrike Falcon Sensor is installed"
        exit 0
    }
    else {
        Write-Output "CrowdStrike Falcon Sensor is not installed"
        exit 1
    }
}
catch {
    Write-Error "Error detecting CrowdStrike Falcon Sensor: $_"
    exit 1
}
