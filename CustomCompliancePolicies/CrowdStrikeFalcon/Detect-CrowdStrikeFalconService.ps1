<#PSScriptInfo
.VERSION        1.0.0
.AUTHOR         Madhu Perera
.DESCRIPTION    Detect CrowdStrike Falcon Service status for Intune Custom Compliance Policy
.NOTES
    FUNCTIONALITY:
    This script checks the status of the CrowdStrike Falcon service (CSFalconService).
    If the service is not running, it will check periodically over a 5-minute window
    before reporting the final status to Intune.
    
    PROCESS OVERVIEW:
    1. Checks if CSFalconService exists on the device
    2. Verifies the service status (Running/Stopped)
    3. If not running, performs periodic checks over 5 minutes
    4. Returns final status as JSON for compliance evaluation
    
    OUTPUT:
    Returns JSON with service status information:
    {
        "ServiceStatus": "Running" | "Stopped" | "NotInstalled",
        "ServiceExists": "true" | "false"
    }
    
    USE CASE:
    - Custom Compliance Policy to ensure CrowdStrike Falcon is running
    - Automated monitoring of endpoint protection status
    - Early detection of service failures or disabled protection
    
.EXAMPLE
    .\Detect-CrowdStrikeFalconService.ps1
#>

[CmdletBinding()]
param()

function Get-ServiceStatusWithRetry {
    <#
    .SYNOPSIS
        Check service status with retry logic over 5-minute window
    .DESCRIPTION
        Checks if the specified service is running. If not, retries every 30 seconds
        for up to 5 minutes before returning the final status.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    
    # Configuration
    $maxDurationSeconds = 300  # 5 minutes total
    $checkIntervalSeconds = 30  # Check every 30 seconds
    $maxRetries = [Math]::Floor($maxDurationSeconds / $checkIntervalSeconds)
    $attempt = 0
    
    # Check if service exists
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if (-not $service) {
        return @{
            ServiceStatus = "NotInstalled"
            ServiceExists = $false
            Message = "CrowdStrike Falcon Service (CSFalconService) not found on this device"
        }
    }
    
    # Loop to check service status with retry
    while ($attempt -lt $maxRetries) {
        $attempt++
        
        # Get current service status
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        $currentStatus = $service.Status.ToString()
        
        # If service is running, return immediately
        if ($currentStatus -eq "Running") {
            return @{
                ServiceStatus = "Running"
                ServiceExists = $true
                Message = "CrowdStrike Falcon Service is running (detected on attempt $attempt)"
            }
        }
        
        # If not the last attempt, wait before checking again
        if ($attempt -lt $maxRetries) {
            Start-Sleep -Seconds $checkIntervalSeconds
        }
    }
    
    # After all retries, service is still not running
    return @{
        ServiceStatus = $currentStatus
        ServiceExists = $true
        Message = "CrowdStrike Falcon Service is $currentStatus after $maxRetries check(s) over $maxDurationSeconds seconds"
    }
}

# Main execution
try {
    $serviceName = "CSFalconService"
    
    # Perform the service check with retry logic
    $result = Get-ServiceStatusWithRetry -ServiceName $serviceName
    
    # Prepare output for Intune Custom Compliance
    $output = @{
        ServiceStatus = $result.ServiceStatus
        ServiceExists = $result.ServiceExists.ToString().ToLower()
    }
    
    # Return JSON output for compliance evaluation
    return $output | ConvertTo-Json -Compress
}
catch {
    # Handle unexpected errors
    $errorOutput = @{
        ServiceStatus = "Error"
        ServiceExists = "false"
    }
    return $errorOutput | ConvertTo-Json -Compress
}
