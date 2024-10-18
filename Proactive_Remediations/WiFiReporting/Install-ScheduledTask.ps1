$ClientName = "Sonitlo"
$Repository = Join-Path -Path $ENV:ProgramData -ChildPath "${ClientName}IntuneManaged\Scripts"
[String] $TaskName = "WiFi_Analysis_v1"
[String] $ScriptName = "WiFi_Analysis.ps1"

# Testing and creating the Directory
try
{
    if (!(Test-Path -Path $Repository -PathType Container))
    {
        New-Item -Path $Repository -Force -ItemType Directory
    }
}
catch
{
    New-Item -Path $Repository -Force -ItemType Directory
}

# Function to Manage Task Creations


function New-WindowsScheduledTask
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $ScriptName,
        [String]
        $ScriptContent,
        [String]
        $TaskName
    )

    # Try and catch blocks for actions
    try
    {
        $FilePath = Join-Path -Path $Repository -ChildPath $ScriptName
        Out-File -FilePath "$FilePath" -Force -ErrorAction Stop -WarningAction SilentlyContinue -InputObject $ScriptContent
    }
    catch
    {
        Write-Error -Message "Could not write the script file" -Category OperationStopped
        return
    }

    # Scheduled Task Action with hidden window and bypass execution policy
    $Action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$FilePath`""

    # Principal set to SYSTEM with highest privileges
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Create logon and daily triggers
    $TriggerAtLogon = New-ScheduledTaskTrigger -AtLogOn
    $TriggerAtLogon.Delay = "PT5M"

    # This is needed because At Logon is not supported with Repetition
    $TempTrigger = New-ScheduledTaskTrigger -Once -At "12:00AM" -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Hours 8)
    #$TempTrigger.Repetition.StopAtDurationEnd = $false

    $TriggerAtLogon.Repetition = $TempTrigger.Repetition

    # Define the task with the action, triggers, and principal
    $Task = New-ScheduledTask -Action $Action -Trigger $TriggerAtLogon -Principal $Principal

    try
    {
        # Check if the task already exists, and if so, remove it before registering a new one
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
        {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }

        # Register the new scheduled task
        Register-ScheduledTask -TaskName $TaskName -InputObject $Task -ErrorAction Stop
    }
    catch
    {
        Write-Error -Message "Could not create scheduled task" -Category OperationStopped
    }
}


# Manage the Script Folders

$ScriptContent = '
# Define the log directory and file
$logDirectory = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\"
$logFile = "$logDirectory\WiFi_NetworkLog.csv"


if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory
}

# Check if the log file exists; if not, create it with headers
if (-not (Test-Path $logFile))
{
    $headers = "UniqueKey,Timestamp,MachineID,UserID,SSID,SignalStrength,NetworkType,IPv4Address,Gateway,DownloadSpeedMbps,PingLatencyMs,DnsServers,NetAdapterStatus,FirewallStatus,TcpConnectionCount,WiFiProfiles,WiFiChannelInfo,SignalQuality,RSSI,WiFiInterfaceDetails,Success,ErrorType"
    $headers | Out-File -FilePath $logFile -Encoding utf8
}

# Initialize variables
$success = 1
$errorType = ""
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$machineID = $env:COMPUTERNAME
$userID = $env:USERNAME
$FileSz = 10 # You can set this to any available size: 5, 10, 20, etc.
$testFileUrl = "http://ipv4.download.thinkbroadband.com/" + $FileSz + "MB.zip"

# Create a unique key
$uniqueKey = "$timestamp|$machineID|$userID"

# Initialize network data variables with nulls
$ssid = ""
$signalStrength = ""
$networkType = ""
$ipv4Address = ""
$gateway = ""
$downloadSpeedMbps = ""
$fastcomDownloadSpeedMbps = ""
$pingLatency = ""
$dnsServers = ""
$netAdapterStatus = ""
$firewallStatus = ""
$tcpConnectionCount = ""
$wifiProfiles = ""
$wifiChannelInfo = ""
$signalQuality = ""
$rssi = ""
$wifiInterfaceDetails = ""

# Begin error trapping for each metric independently

# Collect network interface information
try
{
    $networkInfo = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }
    if ($networkInfo -eq $null) {
        throw "No active network interface found"
    }
}
catch
{
    $success = 0
    $errorType += " | Network interface info error: " + $_.Exception.Message
}

# Wi-Fi Interface Information
try
{
    # Capture the output from netsh wlan show interfaces using cmd /c
    $wlanInfo = cmd /c "netsh wlan show interfaces" | Out-String
    
    # Remove leading empty lines and trim each line
    $wlanInfoLines = $wlanInfo -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
    
    if ($wlanInfoLines) {
        # Join lines into a single string for CSV compatibility
        $wifiInterfaceDetails = $wlanInfoLines -join "; "
        
        # Extract specific details using regex patterns
        $ssidMatch = $wlanInfoLines | Select-String -Pattern "^\s*SSID\s*:\s*(.*)$"
        $ssid = if ($ssidMatch) { $ssidMatch.Matches.Groups[1].Value } else { throw "SSID information not available" }

        $signalMatch = $wlanInfoLines | Select-String -Pattern "^\s*Signal\s*:\s*(.*)$"
        $signalStrength = if ($signalMatch) { $signalMatch.Matches.Groups[1].Value } else { throw "Signal strength information not available" }

        $networkTypeMatch = $wlanInfoLines | Select-String -Pattern "^\s*Network type\s*:\s*(.*)$"
        $networkType = if ($networkTypeMatch) { $networkTypeMatch.Matches.Groups[1].Value } else { throw "Network type information not available" }

        $signalQualityMatch = $wlanInfoLines | Select-String -Pattern "^\s*Signal\s*:\s*(\d+)%$"
        $signalQuality = if ($signalQualityMatch) { $signalQualityMatch.Matches.Groups[1].Value } else { throw "Signal quality information not available" }

        $rssiMatch = $wlanInfoLines | Select-String -Pattern "^\s*Receive rate\s*\(Mbps\)\s*:\s*(.*)$"
        $rssi = if ($rssiMatch) { $rssiMatch.Matches.Groups[1].Value } else { throw "RSSI information not available" }

    }
    else
    {
        throw "No WLAN interfaces information available"
    }
}
catch
{
    $success = 0
    $errorType += " | Wi-Fi interface info error: " + $_.Exception.Message
    Write-Output "Error capturing WLAN interface info: $_"
}

$wlanInfo | Out-File -FilePath "$logDirectory\WiFi_wlanInfoOutput.txt"

# IP and Gateway Information
try
{
    $ipv4Address = if ($networkInfo.IPv4Address) { $networkInfo.IPv4Address.IPAddress } else { throw "IPv4 address not available" }
    $gateway = if ($networkInfo.IPv4DefaultGateway) { $networkInfo.IPv4DefaultGateway.NextHop } else { throw "Gateway information not available" }
}
catch
{
    $success = 0
    $errorType += " | IP/Gateway info error: " + $_.Exception.Message
}

# Perform a ping test to google.com
try
{
    $pingResult = Test-Connection -ComputerName google.com -Count 1 -ErrorAction Stop
    $pingLatency = $pingResult.ResponseTime
}
catch
{
    $success = 0
    $errorType += " | Ping test error: " + $_.Exception.Message
}

# Perform a basic download speed test
try
{
    $ProgressPreference = "SilentlyContinue" # Suppress progress messages
    $startTime = Get-Date
    Invoke-WebRequest -Uri $testFileUrl -OutFile "$env:TEMP\speedtest.tmp" -UseBasicParsing -ErrorAction Stop
    $endTime = Get-Date
    $downloadTime = ($endTime - $startTime).TotalSeconds
    $downloadSpeedMbps = ($FileSz * 8) / $downloadTime # Converting to Mbps
    Remove-Item -Path "$env:TEMP\speedtest.tmp" -Force
}
catch
{
    $success = 0
    $errorType += " | Download speed test error: " + $_.Exception.Message
}

# Reset the progress preference to the default behavior
$ProgressPreference = "Continue"


# Collect DNS Server Information
try
{
    $dnsServers = (Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq "IPv4" }).ServerAddresses -join ";"
    if (-not $dnsServers) { throw "DNS servers information not available" }
}
catch
{
    $success = 0
    $errorType += " | DNS server info error: " + $_.Exception.Message
}

# Collect Network Adapter Status
try
{
    $netAdapterStatus = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" }).InterfaceDescription -join ";"
    if (-not $netAdapterStatus) { throw "Network adapter status not available" }
}
catch {
    $success = 0
    $errorType += " | Network adapter status error: " + $_.Exception.Message
}

# Collect Firewall Status
try
{
    $firewallProfiles = Get-NetFirewallProfile
    $firewallStatus = ($firewallProfiles | Where-Object { $_.Enabled -eq "True" }).Name -join ";"
    if (-not $firewallStatus) { throw "Firewall status not available" }
}
catch
{
    $success = 0
    $errorType += " | Firewall status error: " + $_.Exception.Message
}

# Count TCP Connections
try
{
    $tcpConnectionCount = (Get-NetTCPConnection | Measure-Object).Count
}
catch
{
    $success = 0
    $errorType += " | TCP connection count error: " + $_.Exception.Message
}

# Collect Wi-Fi Network Profile Information
try
{
    $wifiProfiles = (netsh wlan show profiles) | Select-String -Pattern "All User Profile\s*:\s*(.*)" | ForEach-Object { $_.Matches.Groups[1].Value } -join ";"
    if (-not $wifiProfiles) { throw "Wi-Fi profiles information not available" }
}
catch
{
    $success = 0
    $errorType += " | Wi-Fi profiles error: " + $_.Exception.Message
}

# Collect Wi-Fi Channel Information
try
{
    $wifiChannelInfo = (netsh wlan show networks mode=Bssid) | Select-String -Pattern "Channel\s*:\s*(.*)" | ForEach-Object { $_.Matches.Groups[1].Value } -join ";"
    if (-not $wifiChannelInfo) { throw "Wi-Fi channel information not available" }
}
catch
{
    $success = 0
    $errorType += " | Wi-Fi channel info error: " + $_.Exception.Message
}

# Get the current timestamp again to ensure accurate time for the log entry
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Format the data as a CSV row
$logEntry = "$uniqueKey,$timestamp,$machineID,$userID,$ssid,$signalStrength,$networkType,$ipv4Address,$gateway,$downloadSpeedMbps,$pingLatency,$dnsServers,$netAdapterStatus,$firewallStatus,$tcpConnectionCount,$wifiProfiles,$wifiChannelInfo,$signalQuality,$rssi,$wifiInterfaceDetails,$success,$errorType"

# Append the data to the CSV file
$logEntry | Out-File -FilePath $logFile -Append -Encoding utf8

Write-Output "Network information logged successfully."
'
$a=New-WindowsScheduledTask -TaskName $TaskName -ScriptName $ScriptName -ScriptContent $ScriptContent
$ScriptContent = ""

