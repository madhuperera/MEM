# Author : Madhu Perera
# Summary: Deploying a Printer to a PC (V2 - Improved)
# Version: 2.0
# Changes: - Uses modern PowerShell cmdlets instead of VBScript
#          - Better error handling with detailed logging
#          - Parameter validation
#          - Exact match for port detection
#          - SNMP configuration for printer ports
#          - Cleanup of extracted driver files
#          - Fixed typos

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
    [String] $PrinterDriverZipFileName = "PLEASE_CHANGE_ME", # EX: Driver.ZIP (You will need to include this Zipped File along with IntuneWin32 Package)
    [Parameter(Mandatory=$false)]
    [String] $PrinterDriverModelFileName = "PLEASE_CHANGE_ME",  # EX: CNP60MA64.INF (Part of the Driver.ZIP file)
    [Parameter(Mandatory=$false)]
    [Int] $PrinterPortNumber = 9100, # Default RAW port for most printers
    [Parameter(Mandatory=$false)]
    [String] $SNMPCommunity = "public", # SNMP Community string
    [Parameter(Mandatory=$false)]
    [Bool] $EnableSNMP = $true # Enable SNMP for better printer management
)

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
$LogFile = "$env:ProgramData\PrinterDeployment\Deploy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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
    
    if ($PrinterPortIPAddress -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterPortIPAddress" }
    if ($PrinterPortName -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterPortName" }
    if ($PrinterName -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterName" }
    if ($PrinterDriverModelName -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterDriverModelName" }
    if ($PrinterDriverZipFileName -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterDriverZipFileName" }
    if ($PrinterDriverModelFileName -eq "PLEASE_CHANGE_ME") { $InvalidParams += "PrinterDriverModelFileName" }
    
    if ($InvalidParams.Count -gt 0) {
        Write-Log -Message "The following parameters need to be configured: $($InvalidParams -join ', ')" -Level ERROR
        return $false
    }
    
    Write-Log -Message "All parameters validated successfully"
    return $true
}

function Test-PrinterPortExists {
    param (
        [String] $PrinterFPortName
    )
    
    try {
        $Port = Get-PrinterPort -Name $PrinterFPortName -ErrorAction SilentlyContinue
        if ($Port) {
            Write-Log -Message "Printer port '$PrinterFPortName' already exists"
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        Write-Log -Message "Error checking printer port: $($_.Exception.Message)" -Level WARNING
        return $false
    }
}

function Test-PrinterExists {
    param (
        [String] $PrinterFName
    )    

    try {
        # Use Where-Object for exact match to handle special characters like brackets
        $Printer = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $PrinterFName }
        if ($Printer) {
            Write-Log -Message "Printer '$PrinterFName' already exists"
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        Write-Log -Message "Error checking printer: $($_.Exception.Message)" -Level WARNING
        return $false
    }
}

function Test-PrinterDriverExists {
    param (
        [String] $DriverName
    )
    
    try {
        $Driver = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
        if ($Driver) {
            Write-Log -Message "Printer driver '$DriverName' already exists"
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        Write-Log -Message "Error checking printer driver: $($_.Exception.Message)" -Level WARNING
        return $false
    }
}

# ==================== MAIN SCRIPT ====================

Write-Log -Message "=========================================="
Write-Log -Message "Printer Deployment Script V2 Started"
Write-Log -Message "=========================================="

# Validate parameters
if (!(Test-Parameters)) {
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Invalid Parameters"
}

Write-Log -Message "Configuration:"
Write-Log -Message "  Printer Name: $PrinterName"
Write-Log -Message "  Printer Driver: $PrinterDriverModelName"
Write-Log -Message "  Port Name: $PrinterPortName"
Write-Log -Message "  Port IP: $PrinterPortIPAddress"
Write-Log -Message "  Port Number: $PrinterPortNumber"

# Extract and Install the Driver
$DriverZipPath = "$PSScriptRoot\$PrinterDriverZipFileName"
$DriverExtractPath = "$PSScriptRoot\Driver"

Write-Log -Message "Extracting driver from $PrinterDriverZipFileName..."

if (!(Test-Path -Path $DriverZipPath)) {
    Write-Log -Message "Driver ZIP file not found: $DriverZipPath" -Level ERROR
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Driver ZIP Not Found"
}

try {
    # Clean up old extraction if exists
    if (Test-Path -Path $DriverExtractPath) {
        Write-Log -Message "Cleaning up old driver extraction..."
        Remove-Item -Path $DriverExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Expand-Archive -Path $DriverZipPath -DestinationPath "$PSScriptRoot\" -Force
    Write-Log -Message "Driver extracted successfully"
}
catch {
    Write-Log -Message "Failed to extract driver: $($_.Exception.Message)" -Level ERROR
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Driver Extraction Error"
}

if (!(Test-Path -Path $DriverExtractPath)) {
    Write-Log -Message "Driver folder not found after extraction: $DriverExtractPath" -Level ERROR
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Driver Folder Not Found"
}

$DriverINFPath = "$DriverExtractPath\$PrinterDriverModelFileName"
if (!(Test-Path -Path $DriverINFPath)) {
    Write-Log -Message "Driver INF file not found: $DriverINFPath" -Level ERROR
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Driver INF Not Found"
}

# Install the printer driver if not already installed
if (!(Test-PrinterDriverExists -DriverName $PrinterDriverModelName)) {
    Write-Log -Message "Installing printer driver: $PrinterDriverModelName..."
    
    try {
        # Step 1: Add driver package to Windows driver store using pnputil
        Write-Log -Message "Adding driver package to Windows driver store..."
        $pnpResult = & pnputil.exe /add-driver "$DriverINFPath" /install 2>&1
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
            throw "pnputil failed with exit code $LASTEXITCODE. Output: $pnpResult"
        }
        
        Write-Log -Message "Driver package added to driver store successfully"
        
        # Step 2: Install the printer driver
        Write-Log -Message "Installing printer driver from driver store..."
        Add-PrinterDriver -Name $PrinterDriverModelName -ErrorAction Stop
        Write-Log -Message "Printer driver installed successfully"
    }
    catch {
        Write-Log -Message "Failed to install printer driver: $($_.Exception.Message)" -Level ERROR
        Write-Log -Message "pnputil output: $pnpResult" -Level ERROR
        # Cleanup extracted files before exit
        if (Test-Path -Path $DriverExtractPath) {
            Remove-Item -Path $DriverExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Driver Installation Error"
    }
}
else {
    Write-Log -Message "Printer driver already installed, skipping installation"
}

# Install the Printer Port
if (!(Test-PrinterPortExists -PrinterFPortName $PrinterPortName)) {
    Write-Log -Message "Creating printer port: $PrinterPortName..."
    
    try {
        $PortParams = @{
            Name = $PrinterPortName
            PrinterHostAddress = $PrinterPortIPAddress
            PortNumber = $PrinterPortNumber
            ErrorAction = 'Stop'
        }
        
        # Add SNMP parameters if enabled
        if ($EnableSNMP) {
            $PortParams['SNMP'] = 1
            $PortParams['SNMPCommunity'] = $SNMPCommunity
            Write-Log -Message "SNMP enabled with community: $SNMPCommunity"
        }
        
        Add-PrinterPort @PortParams
        Write-Log -Message "Printer port created successfully"
    }
    catch {
        Write-Log -Message "Failed to create printer port: $($_.Exception.Message)" -Level ERROR
        # Cleanup extracted files before exit
        if (Test-Path -Path $DriverExtractPath) {
            Remove-Item -Path $DriverExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Port Creation Error"
    }
}
else {
    Write-Log -Message "Printer port already exists in the system!"
}

# Install the Printer
if (!(Test-PrinterExists -PrinterFName $PrinterName)) {
    Write-Log -Message "Installing printer: $PrinterName..."
    
    try {
        Add-Printer -Name $PrinterName -PortName $PrinterPortName -DriverName $PrinterDriverModelName -ErrorAction Stop
        Write-Log -Message "Printer installed successfully"
    }
    catch {
        Write-Log -Message "Failed to install printer: $($_.Exception.Message)" -Level ERROR
        # Cleanup extracted files before exit
        if (Test-Path -Path $DriverExtractPath) {
            Remove-Item -Path $DriverExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED - Printer Installation Error"
    }
}
else {
    Write-Log -Message "Printer already exists in the system!"
}

# Cleanup extracted driver files
Write-Log -Message "Cleaning up extracted driver files..."
if (Test-Path -Path $DriverExtractPath) {
    try {
        Remove-Item -Path $DriverExtractPath -Recurse -Force -ErrorAction Stop
        Write-Log -Message "Cleanup completed successfully"
    }
    catch {
        Write-Log -Message "Warning: Could not clean up driver files: $($_.Exception.Message)" -Level WARNING
    }
}

Write-Log -Message "=========================================="
Write-Log -Message "Printer Deployment Completed Successfully"
Write-Log -Message "=========================================="

Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
