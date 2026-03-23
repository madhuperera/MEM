param
(
    [String] $S_ScriptName = "PDFXChange_Uninstall",

    # Minimum major version to KEEP. Anything below this gets uninstalled.
    # Example: 10 means versions 9.x, 8.x, 2.x etc. are removed; 10.x is kept.
    [int] $S_KeepMajorVersion = 10
)

# ── Logging Setup ──
$LogDirectory = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$S_ScriptName"
$LogFile = Join-Path -Path $LogDirectory -ChildPath "Uninstall-PDFXChange.log"

if (!(Test-Path -Path $LogDirectory -PathType Container))
{
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

function Write-Log
{
    param
    (
        [String] $Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Write-Host $LogEntry
    $LogEntry | Out-File -FilePath $LogFile -Append -Force -Encoding UTF8
}

Write-Log "========================================"
Write-Log "Script started: $S_ScriptName"
Write-Log "Keep major version: $S_KeepMajorVersion"
Write-Log "========================================"

# ── Step 1: Query all installed PDF-XChange products via Win32_Product (MSI only) ──
# This is the method recommended by Tracker Software (PDF-XChange vendor).
# Equivalent to: wmic product where "Name like '%PDF-XChange%'" list brief
Write-Log "Querying Win32_Product for PDF-XChange installations..."
$AllPDFXChange = Get-CimInstance -ClassName Win32_Product -ErrorAction Stop |
    Where-Object { $_.Name -like "*PDF-XChange*" }

if ($null -eq $AllPDFXChange -or @($AllPDFXChange).Count -eq 0)
{
    Write-Log "No PDF-XChange products found. Nothing to uninstall."
    Write-Log "Script completed successfully."
    exit 0
}

Write-Log "Installed PDF-XChange products:"
foreach ($Product in $AllPDFXChange)
{
    Write-Log "  - $($Product.Name)  |  Version: $($Product.Version)  |  GUID: $($Product.IdentifyingNumber)"
}

# ── Step 2: Filter to products older than the keep version ──
$ProductsToRemove = @($AllPDFXChange | Where-Object {
    try
    {
        $MajorVersion = [int]($_.Version -split '\.')[0]
        $MajorVersion -lt $S_KeepMajorVersion
    }
    catch
    {
        # If version can't be parsed, flag it for removal to be safe
        $true
    }
})

if ($ProductsToRemove.Count -eq 0)
{
    Write-Log "No PDF-XChange products older than major version $S_KeepMajorVersion found. Nothing to remove."
    Write-Log "Script completed successfully."
    exit 0
}

Write-Log "$($ProductsToRemove.Count) product(s) older than major version $S_KeepMajorVersion to remove:"
foreach ($Product in $ProductsToRemove)
{
    Write-Log "  - $($Product.Name)  |  Version: $($Product.Version)"
}

# ── Step 3: Force-stop any running PDF-XChange processes ──
Write-Log "Checking for running PDF-XChange processes..."
$RunningProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "PDFX*" -or $_.ProcessName -like "PDF-XChange*" }

if ($null -ne $RunningProcesses -and @($RunningProcesses).Count -gt 0)
{
    foreach ($Proc in $RunningProcesses)
    {
        Write-Log "  Stopping process: $($Proc.ProcessName) (PID: $($Proc.Id))"
        try
        {
            $Proc | Stop-Process -Force -ErrorAction Stop
        }
        catch
        {
            Write-Log "  WARNING: Could not stop $($Proc.ProcessName) - $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds 5

    $StillRunning = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "PDFX*" -or $_.ProcessName -like "PDF-XChange*" }
    if ($null -ne $StillRunning -and @($StillRunning).Count -gt 0)
    {
        Write-Log "  WARNING: Some PDF-XChange processes could not be stopped. Proceeding anyway."
    }
    else
    {
        Write-Log "  All PDF-XChange processes stopped."
    }
}
else
{
    Write-Log "  No running PDF-XChange processes found."
}

# ── Step 4: Uninstall each old product silently (one at a time) ──
# Equivalent to: wmic product where "Name like '%PDF-XChange%' and Version like '9.%'" call uninstall
[bool] $UninstallFailed = $false
[int] $WaitIntervalSeconds = 15
[int] $WaitTimeoutSeconds = 600

foreach ($Product in $ProductsToRemove)
{
    Write-Log "Uninstalling: $($Product.Name) ($($Product.Version))..."

    try
    {
        $Result = Invoke-CimMethod -InputObject $Product -MethodName Uninstall -ErrorAction Stop
        if ($Result.ReturnValue -eq 0)
        {
            Write-Log "  Uninstall command succeeded for $($Product.Name). Waiting for removal to complete..."
        }
        else
        {
            Write-Log "  WARNING: Uninstall returned code $($Result.ReturnValue) for $($Product.Name)"
            $UninstallFailed = $true
            continue
        }
    }
    catch
    {
        Write-Log "  ERROR: Failed to uninstall $($Product.Name) - $($_.Exception.Message)"
        $UninstallFailed = $true
        continue
    }

    # Wait loop: confirm this product is fully removed before moving to the next
    [int] $ElapsedSeconds = 0
    [bool] $StillInstalled = $true

    while ($StillInstalled -and $ElapsedSeconds -lt $WaitTimeoutSeconds)
    {
        Start-Sleep -Seconds $WaitIntervalSeconds
        $ElapsedSeconds += $WaitIntervalSeconds

        $CheckProduct = Get-CimInstance -ClassName Win32_Product -ErrorAction SilentlyContinue |
            Where-Object { $_.IdentifyingNumber -eq $Product.IdentifyingNumber }

        if ($null -eq $CheckProduct)
        {
            $StillInstalled = $false
            Write-Log "  Confirmed removed: $($Product.Name) (after ${ElapsedSeconds}s)"
        }
        else
        {
            Write-Log "  Still installed, waiting... (${ElapsedSeconds}s / ${WaitTimeoutSeconds}s)"
        }
    }

    if ($StillInstalled)
    {
        Write-Log "  WARNING: $($Product.Name) still detected after ${WaitTimeoutSeconds}s timeout."
        $UninstallFailed = $true
    }
}

# ── Step 5: Final verification ──
Write-Log "Final verification..."
$RemainingOld = Get-CimInstance -ClassName Win32_Product -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*PDF-XChange*" } |
    Where-Object {
        try { [int]($_.Version -split '\.')[0] -lt $S_KeepMajorVersion } catch { $true }
    }

if ($null -ne $RemainingOld -and @($RemainingOld).Count -gt 0)
{
    Write-Log "FAILED: $(@($RemainingOld).Count) old PDF-XChange product(s) still detected:"
    foreach ($Remaining in $RemainingOld)
    {
        Write-Log "  - $($Remaining.Name) ($($Remaining.Version))"
    }
    Write-Log "Script completed with errors."
    exit 1
}
else
{
    Write-Log "All old PDF-XChange products successfully removed."
    $Kept = Get-CimInstance -ClassName Win32_Product -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*PDF-XChange*" }
    if ($null -ne $Kept)
    {
        Write-Log "Remaining (kept):"
        foreach ($K in $Kept)
        {
            Write-Log "  - $($K.Name) ($($K.Version))"
        }
    }
    Write-Log "Script completed successfully."
    exit 0
}