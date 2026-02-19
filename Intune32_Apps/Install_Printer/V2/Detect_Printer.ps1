# Author : Madhu Perera
# Summary: Detection Script for Printer Deployment (V2 - Improved)
# Version: 2.0
# Changes: - Better validation logic with detailed checks
#          - Matching parameters with Deploy script
#          - Port name validation added
#          - Logging capability
#          - Better error reporting

# ------------ MEM VARIABLES ----------------
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$false)]
    [String] $PrinterPortIPAddress = "PLEASE_CHANGE_ME", # EX: 192.168.100.100
    [Parameter(Mandatory=$false)]
    [String] $PrinterPortName = "PLEASE_CHANGE_ME", # EX: 192.168.100.100
    [Parameter(Mandatory=$false)]
    [String] $PrinterName = "PLEASE_CHANGE_ME", # EX: Canon imageRUNNER (Sonitlo Managed)
    [Parameter(Mandatory=$false)]
    [String] $PrinterDriverModelName = "PLEASE_CHANGE_ME", # EX: Canon Generic Plus PCL6
    [Parameter(Mandatory=$false)]
    [String] $PrinterDriverZipFileName = "PLEASE_CHANGE_ME", # EX: Driver.ZIP (Not used in detection but kept for consistency)
    [Parameter(Mandatory=$false)]
    [String] $PrinterDriverModelFileName = "PLEASE_CHANGE_ME",  # EX: CNP60MA64.INF (Not used in detection but kept for consistency)
    [Parameter(Mandatory=$false)]
    [Int] $PrinterPortNumber = 9100, # Default RAW port for most printers
    [Parameter(Mandatory=$false)]
    [String] $SNMPCommunity = "public", # SNMP Community string (not validated)
    [Parameter(Mandatory=$false)]
    [Bool] $EnableSNMP = $true # Enable SNMP (not validated in detection)
)

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
$LogFile = "$env:ProgramData\PrinterDeployment\Detect_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log directory if it doesn't exist
$LogDir = Split-Path -Path $LogFile -Parent
if (!(Test-Path -Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "$Timestamp [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    
    # Also write to console
    switch ($Level) {
        'ERROR' { Write-Host $LogMessage -ForegroundColor Red }
        'WARNING' { Write-Host $LogMessage -ForegroundColor Yellow }
        default { Write-Host $LogMessage }
    }
}

function Update-OutputOnExit {
    param (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Log -Message "Detection Result: $F_Message" -Level $(if ($F_ExitCode) { 'ERROR' } else { 'INFO' })
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode) {
        exit 1
    }
    else {
        exit 0
    }
}

# ==================== MAIN DETECTION LOGIC ====================

Write-Log -Message "=========================================="
Write-Log -Message "Printer Detection Script V2 Started"
Write-Log -Message "=========================================="

Write-Log -Message "Detection Configuration:"
Write-Log -Message "  Printer Name: $PrinterName"
Write-Log -Message "  Expected Driver: $PrinterDriverModelName"
Write-Log -Message "  Expected Port Name: $PrinterPortName"
Write-Log -Message "  Expected Port IP: $PrinterPortIPAddress"

try {
    # Check if printer exists
    Write-Log -Message "Checking if printer '$PrinterName' exists..."
    # Use Where-Object for exact match to handle special characters like brackets
    $Printer = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $PrinterName }
    
    if (!$Printer) {
        Write-Log -Message "Printer '$PrinterName' not found" -Level WARNING
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Printer Not Found"
    }
    
    Write-Log -Message "Printer found: $($Printer.Name)"
    Write-Log -Message "  Current Driver: $($Printer.DriverName)"
    Write-Log -Message "  Current Port: $($Printer.PortName)"
    
    # Check if driver matches
    if ($Printer.DriverName -ne $PrinterDriverModelName) {
        Write-Log -Message "Driver mismatch - Expected: '$PrinterDriverModelName', Found: '$($Printer.DriverName)'" -Level WARNING
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Wrong Driver"
    }
    
    Write-Log -Message "Driver matches expected: $PrinterDriverModelName"
    
    # Check if port name matches
    if ($Printer.PortName -ne $PrinterPortName) {
        Write-Log -Message "Port name mismatch - Expected: '$PrinterPortName', Found: '$($Printer.PortName)'" -Level WARNING
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Wrong Port Name"
    }
    
    Write-Log -Message "Port name matches expected: $PrinterPortName"
    
    # Check if printer port exists and has correct IP
    Write-Log -Message "Checking printer port configuration..."
    $PrinterPort = Get-PrinterPort -Name $Printer.PortName -ErrorAction SilentlyContinue
    
    if (!$PrinterPort) {
        Write-Log -Message "Printer port '$($Printer.PortName)' not found" -Level WARNING
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Port Not Found"
    }
    
    Write-Log -Message "Printer port found: $($PrinterPort.Name)"
    Write-Log -Message "  Port IP Address: $($PrinterPort.PrinterHostAddress)"
    
    # Check if IP address matches
    if ($PrinterPort.PrinterHostAddress -ne $PrinterPortIPAddress) {
        Write-Log -Message "IP address mismatch - Expected: '$PrinterPortIPAddress', Found: '$($PrinterPort.PrinterHostAddress)'" -Level WARNING
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Wrong IP Address"
    }
    
    Write-Log -Message "IP address matches expected: $PrinterPortIPAddress"
    
    # All checks passed
    Write-Log -Message "=========================================="
    Write-Log -Message "All Detection Checks Passed Successfully"
    Write-Log -Message "=========================================="
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
catch {
    Write-Log -Message "Detection error occurred: $($_.Exception.Message)" -Level ERROR
    Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Exception"
}
