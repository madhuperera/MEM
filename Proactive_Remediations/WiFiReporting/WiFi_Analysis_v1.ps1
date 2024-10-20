# Define the log directory and file
= "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\"
= "\WiFi_NetworkLog.csv"

# Create the directory if it doesn't exist
if (-not (Test-Path ))
{
   New-Item -Path  -ItemType Directory
}

# Check if the log file exists; if not, create it with headers
if (-not (Test-Path ))
{
    = "UniqueKey,Timestamp,MachineID,UserID,SSID,SignalStrength,NetworkType,IPv4Address,Gateway,DownloadSpeedMbps,PingLatencyMs,DnsServers,NetAdapterStatus,FirewallStatus,TcpConnectionCount,WiFiProfiles,WiFiChannelInfo,SignalQuality,RSSI,WiFiInterfaceDetails,Success,ErrorType"
    | Out-File -FilePath  -Encoding utf8
}

# Initialize variables
= 1
= ""
= Get-Date -Format "yyyy-MM-dd HH:mm:ss"
= 46E7719A-97A9-4
= WDAGUtilityAccount
= 10 # You can set this to any available size: 5, 10, 20, etc.
= "http://ipv4.download.thinkbroadband.com/" +  + "MB.zip"

# Create a unique key
= "||"

# Initialize network data variables with nulls
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""
= ""

# Begin error trapping for each metric independently

# Collect network interface information
try
{
    = Get-NetIPConfiguration | Where-Object { .IPv4DefaultGateway -ne  }
   if ( -eq ) {
       throw "No active network interface found"
   }
}
catch
{
    = 0
    += " | Network interface info error: " + .Exception.Message
}

# Wi-Fi Interface Information
try
{
   # Capture the output from netsh wlan show interfaces using cmd /c
    = cmd /c "netsh wlan show interfaces" | Out-String
   
   # Remove leading empty lines and trim each line
    =  -split "
?
" | Where-Object { .Trim() -ne "" }
   
   if () {
       # Join lines into a single string for CSV compatibility
        =  -join "; "
       
       # Extract specific details using regex patterns
        =  | Select-String -Pattern "^\s*SSID\s*:\s*(.*)$"
        = if () { .Matches.Groups[1].Value } else { throw "SSID information not available" }

        =  | Select-String -Pattern "^\s*Signal\s*:\s*(.*)$"
        = if () { .Matches.Groups[1].Value } else { throw "Signal strength information not available" }

        =  | Select-String -Pattern "^\s*Network type\s*:\s*(.*)$"
        = if () { .Matches.Groups[1].Value } else { throw "Network type information not available" }

        =  | Select-String -Pattern "^\s*Signal\s*:\s*(\d+)%$"
        = if () { .Matches.Groups[1].Value } else { throw "Signal quality information not available" }

        =  | Select-String -Pattern "^\s*Receive rate\s*\(Mbps\)\s*:\s*(.*)$"
        = if () { .Matches.Groups[1].Value } else { throw "RSSI information not available" }

   }
   else
   {
       throw "No WLAN interfaces information available"
   }
}
catch
{
    = 0
    += " | Wi-Fi interface info error: " + .Exception.Message
   Write-Output "Error capturing WLAN interface info: "
}

| Out-File -FilePath "\WiFi_wlanInfoOutput.txt"

# IP and Gateway Information
try
{
    = if (.IPv4Address) { .IPv4Address.IPAddress } else { throw "IPv4 address not available" }
    = if (.IPv4DefaultGateway) { .IPv4DefaultGateway.NextHop } else { throw "Gateway information not available" }
}
catch
{
    = 0
    += " | IP/Gateway info error: " + .Exception.Message
}

# Perform a ping test to google.com
try
{
    = Test-Connection -ComputerName google.com -Count 1 -ErrorAction Stop
    = .ResponseTime
}
catch
{
    = 0
    += " | Ping test error: " + .Exception.Message
}

# Perform a basic download speed test
try
{
   Continue = 'SilentlyContinue' # Suppress progress messages
    = Get-Date
   Invoke-WebRequest -Uri  -OutFile "C:\Users\WDAGUT~1\AppData\Local\Temp\speedtest.tmp" -UseBasicParsing -ErrorAction Stop
    = Get-Date
    = ( - ).TotalSeconds
    = ( * 8) /  # Converting to Mbps
   Remove-Item -Path "C:\Users\WDAGUT~1\AppData\Local\Temp\speedtest.tmp" -Force
}
catch
{
    = 0
    += " | Download speed test error: " + .Exception.Message
}

# Reset the progress preference to the default behavior
Continue = 'Continue'


# Collect DNS Server Information
try
{
    = (Get-DnsClientServerAddress | Where-Object { .AddressFamily -eq 'IPv4' }).ServerAddresses -join ";"
   if (-not ) { throw "DNS servers information not available" }
}
catch
{
    = 0
    += " | DNS server info error: " + .Exception.Message
}

# Collect Network Adapter Status
try
{
    = (Get-NetAdapter | Where-Object { .Status -eq 'Up' }).InterfaceDescription -join ";"
   if (-not ) { throw "Network adapter status not available" }
}
catch {
    = 0
    += " | Network adapter status error: " + .Exception.Message
}

# Collect Firewall Status
try
{
    = Get-NetFirewallProfile
    = ( | Where-Object { .Enabled -eq 'True' }).Name -join ";"
   if (-not ) { throw "Firewall status not available" }
}
catch
{
    = 0
    += " | Firewall status error: " + .Exception.Message
}

# Count TCP Connections
try
{
    = (Get-NetTCPConnection | Measure-Object).Count
}
catch
{
    = 0
    += " | TCP connection count error: " + .Exception.Message
}

# Collect Wi-Fi Network Profile Information
try
{
    = (netsh wlan show profiles) | Select-String -Pattern "All User Profile\s*:\s*(.*)" | ForEach-Object { .Matches.Groups[1].Value } -join ";"
   if (-not ) { throw "Wi-Fi profiles information not available" }
}
catch
{
    = 0
    += " | Wi-Fi profiles error: " + .Exception.Message
}

# Collect Wi-Fi Channel Information
try
{
    = (netsh wlan show networks mode=Bssid) | Select-String -Pattern "Channel\s*:\s*(.*)" | ForEach-Object { .Matches.Groups[1].Value } -join ";"
   if (-not ) { throw "Wi-Fi channel information not available" }
}
catch
{
    = 0
    += " | Wi-Fi channel info error: " + .Exception.Message
}

# Get the current timestamp again to ensure accurate time for the log entry
= Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Format the data as a CSV row
= ",,,,,,,,,,,,,,,,,,,,,"

# Append the data to the CSV file
| Out-File -FilePath  -Append -Encoding utf8

Write-Output "Network information logged successfully."
