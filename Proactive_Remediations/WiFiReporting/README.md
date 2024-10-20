# WiFi Reporting and Remediation Scripts

This repository contains PowerShell scripts designed for managing scheduled tasks related to Wi-Fi reporting in Microsoft Intune. The scripts are divided into two sections:
- **WiFiReporting**: Configures and manages scheduled tasks to gather and analyze Wi-Fi information for a specific group of devices.
- **Cleanup**: Detects and removes the scheduled tasks for devices not in the targeted group.

## Folder Structure
```plaintext
WiFiReporting/
    Readme.md
    Detect-ScheduledTask.ps1
    Installed-ScheduledTask.ps1
    WiFi_Analysis_v1.ps1
Cleanup/
    Detect-ScheduledTask.ps1
    Remove-ScheduledTask.ps1

## WiFiReporting

### Overview
The scripts in this folder are used to set up a scheduled task on a group of devices via Microsoft Intune. The scheduled task will regularly collect and log Wi-Fi network information, such as SSID, signal strength, IP address, and more.

### Scripts

- **Detect-ScheduledTask.ps1**
  - Detects if the Wi-Fi reporting scheduled task is present on the device.
  - Returns a boolean value to indicate task presence.

- **Installed-ScheduledTask.ps1**
  - Installs the scheduled task that runs `WiFi_Analysis_v1.ps1` on a regular basis.
  - Ensures the task is configured to run in the background and log Wi-Fi details.

- **WiFi_Analysis_v1.ps1**
  - Collects Wi-Fi and network information, such as SSID, signal strength, network type, and IP address.
  - Logs the collected data to `$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WiFi_NetworkLog.csv`.

## Cleanup

### Overview
These scripts are used to remove the scheduled task from devices that are not part of the targeted group.

### Scripts

- **Detect-ScheduledTask.ps1**
  - Detects if the Wi-Fi reporting scheduled task is present on the device.
  - Used to check if removal is necessary.

- **Remove-ScheduledTask.ps1**
  - Removes the Wi-Fi reporting scheduled task from devices that should no longer have it.

## Usage

1. **Intune Configuration**:
   - Upload the remediation scripts to Microsoft Intune as PowerShell scripts.
   - Assign the **WiFiReporting** scripts to the group of devices you want to monitor.
   - Assign the **Cleanup** scripts to devices outside the targeted group to remove the scheduled task.

2. **Wi-Fi Analysis**:
   - Once the scheduled task is configured, it will regularly log Wi-Fi network details in CSV format for further analysis.
