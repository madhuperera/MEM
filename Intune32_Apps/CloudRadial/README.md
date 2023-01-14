# CloudRadial Detection Script

This PowerShell script checks if the CloudRadial app is installed on a device. 

## Usage

To use this script, run the following command in PowerShell: 
```powershell
.\CloudRadialDetection.ps1
```
## Output

The script will output one of the following messages:

- "CloudRadial Service is already running" if the CloudRadial app is installed and running on the device
- "CloudRadial Service is Not Running" if the CloudRadial app is not installed or not running on the device

Additionally, the script will return a exit code of `0` if the CloudRadial app is running, and a exit code of `1` if the CloudRadial app is not running. This can be useful for use in automation tasks.

## Note
This script is intended to be used with Microsoft Intune Win32 App.
