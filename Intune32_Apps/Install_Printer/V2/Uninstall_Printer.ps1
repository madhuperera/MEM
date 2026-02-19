# Author : Madhu Perera
# Summary: Uninstalling a Printer from a PC (V2)
# Version: 2.0
# Note: This script removes the printer and optionally the port, but NOT the driver
#       (Drivers are left installed as they may be used by other printers)

# ______________________________________________________________

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
    [String] $PrinterDriverZipFileName = "PLEASE_CHANGE_ME", # EX: Driver.ZIP (Not used in uninstall)
    [Parameter(Mandatory=$false)]
    [String] $PrinterDriverModelFileName = "PLEASE_CHANGE_ME",  # EX: CNP60MA64.INF (Not used in uninstall)
    [Parameter(Mandatory=$false)]
    [Int] $PrinterPortNumber = 9100,
    [Parameter(Mandatory=$false)]
    [String] $SNMPCommunity = "public",
    [Parameter(Mandatory=$false)]
    [Bool] $EnableSNMP = $true,
    [Parameter(Mandatory=$false)]
    [Bool] $RemovePort = $false  # Set to $false if you want to keep the port for potential reuse
)

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
$LogFile = "$env:ProgramData\PrinterDeployment\Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log directory if it doesn't exist
$LogDir = Split-Path -Path $LogFile -Parent
if (!(Test-Path -Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
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
    
    Write-Log -Message "Exit Status: $F_Message" -Level $(if ($F_ExitCode) { 'ERROR' } else { 'INFO' })
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode) {
        exit 1
    }
    else {
        exit 0
    }
}

function Test-Parameters {
    Write-Log -Message "Validating parameters..."
    
    $InvalidParams = @()
    
    if ($PrinterName -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterName" }
    
    if ($RemovePort) {
        if ($PrinterPortName -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterPortName" }
    }
    
    if ($InvalidParams.Count -gt 0) {
        Write-Log -Message "The following parameters need to be configured: $($InvalidParams -join ', ')" -Level ERROR
        return $false
    }
    
    Write-Log -Message "All parameters validated successfully"
    return $true
}

function Test-PrinterPortInUse {
    param (
        [String] $PortName
    )
    
    try {
        # Check if any other printers are using this port
        $PrintersUsingPort = Get-Printer | Where-Object { $_.PortName -eq $PortName }
        
        if ($PrintersUsingPort) {
            Write-Log -Message "Port '$PortName' is still in use by the following printers: $($PrintersUsingPort.Name -join ', ')" -Level INFO
            return $true
        }
        else {
            Write-Log -Message "Port '$PortName' is not in use by any printers"
            return $false
        }
    }
    catch {
        Write-Log -Message "Error checking port usage: $($_.Exception.Message)" -Level WARNING
        return $true  # Assume in use if we can't check
    }
}

# ==================== MAIN SCRIPT ====================

Write-Log -Message "=========================================="
Write-Log -Message "Printer Uninstall Script V2 Started"
Write-Log -Message "=========================================="

# Validate parameters
if (!(Test-Parameters)) {
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Invalid Parameters"
}

Write-Log -Message "Configuration:"
Write-Log -Message "  Printer Name: $PrinterName"
Write-Log -Message "  Port Name: $PrinterPortName"
Write-Log -Message "  Remove Port: $RemovePort"

# Check if printer exists
Write-Log -Message "Checking if printer '$PrinterName' exists..."
# Use Where-Object for exact match to handle special characters like brackets
$Printer = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $PrinterName }

if (!$Printer) {
    Write-Log -Message "Printer '$PrinterName' not found. Nothing to uninstall." -Level WARNING
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS - Already Removed"
}

Write-Log -Message "Printer found: $($Printer.Name) on port: $($Printer.PortName)"

# Remove the printer
Write-Log -Message "Removing printer: $PrinterName..."
try {
    # Use InputObject to avoid wildcard issues with special characters in printer name
    Remove-Printer -InputObject $Printer -ErrorAction Stop
    Write-Log -Message "Printer removed successfully"
}
catch {
    Write-Log -Message "Failed to remove printer: $($_.Exception.Message)" -Level ERROR
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Printer Removal Error"
}

# Remove the printer port if requested and not in use
if ($RemovePort) {
    Write-Log -Message "Checking if port should be removed..."
    
    # Check if port exists
    $Port = Get-PrinterPort -Name $PrinterPortName -ErrorAction SilentlyContinue
    
    if (!$Port) {
        Write-Log -Message "Port '$PrinterPortName' not found. Skipping port removal." -Level WARNING
    }
    else {
        # Check if port is still in use by other printers
        if (Test-PrinterPortInUse -PortName $PrinterPortName) {
            Write-Log -Message "Port '$PrinterPortName' is still in use by other printers. Skipping removal." -Level WARNING
        }
        else {
            Write-Log -Message "Removing printer port: $PrinterPortName..."
            try {
                Remove-PrinterPort -Name $PrinterPortName -ErrorAction Stop
                Write-Log -Message "Printer port removed successfully"
            }
            catch {
                Write-Log -Message "Failed to remove printer port: $($_.Exception.Message)" -Level WARNING
                Write-Log -Message "Continuing despite port removal failure..." -Level WARNING
            }
        }
    }
}
else {
    Write-Log -Message "Port removal disabled. Keeping port: $PrinterPortName"
}

Write-Log -Message "==========================================="
Write-Log -Message "NOTE: Printer driver was NOT removed"
Write-Log -Message "Driver '$PrinterDriverModelName' remains installed for potential reuse"
Write-Log -Message "If you need to remove the driver, use Remove-PrinterDriver cmdlet manually"
Write-Log -Message "==========================================="

Write-Log -Message "=========================================="
Write-Log -Message "Printer Uninstall Completed Successfully"
Write-Log -Message "=========================================="

Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
