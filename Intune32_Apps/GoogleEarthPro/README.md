# Google Earth Pro Installation Scripts

## Introduction
These PowerShell scripts are designed to detect, install, and uninstall Google Earth Pro using the Winget package manager.

This package manager is required for the scripts to work. Please ensure it's installed before proceeding.

### Winget Package Manager
Winget is a command-line utility that allows you to discover, install, upgrade, remove, and configure applications on Windows 10 computers. 
For more information and installation instructions, visit the [Winget GitHub repository](https://github.com/microsoft/winget-cli).

## Detection Script
This script checks if Google Earth Pro is installed on the system using the Winget package manager.

```powershell
# This app is dependent on WINGET Package Manager: https://github.com/madhuperera/MEM/tree/a6bf94109d3f4ff1f537aa1efa9e1b35f6a66fa6/Intune32_Apps/WINGET

[String] $S_WingetAppID = "Google.EarthPro"

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

function Test-WingetPackageManagerInstalled
{
    if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller)
    {
        return $true
    }
    else 
    {
        return $false
    }
}


function Test-WingetAppInstalled
{
    # Name of the Application
    param 
    (
        [string] $F_WingetAppId
    )

    if ((winget list $F_WingetAppId) -match $F_WingetAppId)
    {
        return $true
    }
    else
    {
        return $false
    }
}

if (!(Test-WingetPackageManagerInstalled))
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
else
{
    if (Test-WingetAppInstalled -F_WingetAppId $S_WingetAppID)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    else
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}

```

## Installation Script
This script installs Google Earth Pro if it's not already installed. If Winget is not found, it exits with an error.

```powershell
# Insert the installation script here
```

## Uninstallation Script
This script uninstalls Google Earth Pro if it's installed. If Winget is not found, it exits with an error.

```powershell
# Insert the uninstallation script here
```

## Usage
1. Make sure Winget package manager is installed.
2. Run the respective PowerShell script based on your requirement:
   - **Detection**: Use the detection script to check if Google Earth Pro is installed.
   - **Installation**: Use the installation script to install Google Earth Pro.
   - **Uninstallation**: Use the uninstallation script to remove Google Earth Pro.
3. Follow the prompts and instructions provided by the scripts.

## Important Notes
- These scripts are designed for use on Windows 10.
- Ensure that PowerShell execution policy allows running scripts.
- Make sure to run the scripts with appropriate permissions (e.g., Run as Administrator).

## Contributions
Contributions are welcome! If you find any issues or have suggestions for improvements, feel free to submit a pull request.

## License
This project is licensed under the [MIT License](LICENSE).
