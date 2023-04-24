# Author : Madhu Perera
# Summary: Monitoring to see if all Defender Services and features are enabled and running

# ------------------------------- START -------------------------------

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
function Update-OutputOnExit
{
    param
    (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode)
    {
        exit 1
    }
    else
    {
        exit 0
    }
}



function Get-ServiceStatus
{
    # Basic function to check the Service and return the status
    # If the service is not running, it will attempt to start the service once
    param
    (
        [String] $ServiceName
    )
    
    $ServiceStatus = (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status
    
    switch ($ServiceStatus)
    {
        "Stopped"
        {
            Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
            $ServiceStatus = (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status
        }
        Default
        {
            return $ServiceStatus
        }
    }

    return $ServiceStatus
}

$DefenderStatus = Get-MpComputerStatus

$DefenderFirewallServiceStatus = Get-ServiceStatus -ServiceName "mpssvc"
$DefenderATPServiceStatus = Get-ServiceStatus -ServiceName "Sense"
$DefenderNetInspectionServiceStatus = Get-ServiceStatus -ServiceName "WdNisSvc"
$DefenderAVServiceStatus = Get-ServiceStatus -ServiceName "WinDefend"


$AMServiceEnabled = $DefenderStatus.AMServiceEnabled
$AntispywareEnabled = $DefenderStatus.AntispywareEnabled
$AntivirusEnabled = $DefenderStatus.AntivirusEnabled
$BehaviorMonitorEnabled = $DefenderStatus.BehaviorMonitorEnabled
$IoavProtectionEnabled = $DefenderStatus.IoavProtectionEnabled
$IsTamperProtected = $DefenderStatus.IsTamperProtected
$NISEnabled = $DefenderStatus.NISEnabled
$OnAccessProtectionEnabled = $DefenderStatus.OnAccessProtectionEnabled
$RealTimeProtectionEnabled = $DefenderStatus.RealTimeProtectionEnabled

[String] $Output = ""

$AllProtectionsOn = $false
if ($AMServiceEnabled -and $AntispywareEnabled -and $AntivirusEnabled `
    -and $BehaviorMonitorEnabled -and $IoavProtectionEnabled -and $IsTamperProtected `
    -and $NISEnabled -and $OnAccessProtectionEnabled -and $RealTimeProtectionEnabled `
    -and ($DefenderFirewallServiceStatus -eq "Running") `
    -and ($DefenderATPServiceStatus -eq "Running") `
    -and ($DefenderNetInspectionServiceStatus -eq "Running") `
    -and ($DefenderAVServiceStatus -eq "Running"))
{
    $AllProtectionsOn = $true
}

if ($AllProtectionsOn)
{
    $Output = "All Defender Services are running." + "----" + "`n`n$DefenderFirewallServiceStatus | Windows Defender Firewall" + " --- " + "`n$DefenderATPServiceStatus | Windows Defender Advanced Threat Protection Service" + `
    " --- " + "`n$DefenderNetInspectionServiceStatus | Microsoft Defender Antivirus Network Inspection Service" + `
    " --- " + "`n$DefenderAVServiceStatus | Microsoft Defender Antivirus Service" + `
    " --- " + "`n`n$AMServiceEnabled | Activation of the antimalware service" + `
    " --- " + "`n$AntispywareEnabled | Antispyware protection activation status" + `
    " --- " + "`n$AntivirusEnabled | Antivirus protection activation status" + `
    " --- " + "`n$BehaviorMonitorEnabled | Antivirus behavior monitor status" + `
    " --- " + "`n$IoavProtectionEnabled | Office Antivirus protection status" + `
    " --- " + "`n$IsTamperProtected | Antivirus Tamper Protection Status" + `
    " --- " + "`n$NISEnabled | Antivirus Network Protection (Web Filtering)" + `
    " --- " + "`n$OnAccessProtectionEnabled | Antivirus Access Protection Status" + `
    " --- " + "`n$RealTimeProtectionEnabled | Antivirus Realtime Scanning Status"
    
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message $Output
}
else
{
    $Output = "Some or all Defender Services are NOT running!" + "----" + "`n`n$DefenderFirewallServiceStatus | Windows Defender Firewall" + " --- " + "`n$DefenderATPServiceStatus | Windows Defender Advanced Threat Protection Service" + `
    " --- " + "`n$DefenderNetInspectionServiceStatus | Microsoft Defender Antivirus Network Inspection Service" + `
    " --- " + "`n$DefenderAVServiceStatus | Microsoft Defender Antivirus Service" + `
    " --- " + "`n`n$AMServiceEnabled | Activation of the antimalware service" + `
    " --- " + "`n$AntispywareEnabled | Antispyware protection activation status" + `
    " --- " + "`n$AntivirusEnabled | Antivirus protection activation status" + `
    " --- " + "`n$BehaviorMonitorEnabled | Antivirus behavior monitor status" + `
    " --- " + "`n$IoavProtectionEnabled | Office Antivirus protection status" + `
    " --- " + "`n$IsTamperProtected | Antivirus Tamper Protection Status" + `
    " --- " + "`n$NISEnabled | Antivirus Network Protection (Web Filtering)" + `
    " --- " + "`n$OnAccessProtectionEnabled | Antivirus Access Protection Status" + `
    " --- " + "`n$RealTimeProtectionEnabled | Antivirus Realtime Scanning Status"

    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message $Output
}
