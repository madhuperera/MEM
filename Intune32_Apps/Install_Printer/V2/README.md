# How to Install a Printer using these Scripts (V2 - Improved)

You can use these improved scripts to deploy printers and drivers to your Windows 10 and 11 devices using Microsoft Endpoint Manager (Intune).

## What's New in V2?

### Major Improvements:
✅ **Modern PowerShell Cmdlets** - Replaced legacy VBScript with native PowerShell `Add-PrinterDriver` cmdlet  
✅ **Locale-Independent** - No longer depends on `en-US` folder, works on all Windows language versions  
✅ **Better Error Handling** - Detailed error messages with specific failure reasons  
✅ **Comprehensive Logging** - All operations logged to `C:\ProgramData\PrinterDeployment\` for troubleshooting  
✅ **Parameter Validation** - Checks if parameters are configured before attempting installation  
✅ **Exact Port Matching** - Fixed wildcard matching issue that could match wrong ports  
✅ **Driver Cleanup** - Automatically removes extracted driver files after installation  
✅ **Port Validation** - Detection script now validates both port name and IP address  
✅ **SNMP Configuration** - Optional SNMP support for better printer management  
✅ **Uninstall Script** - New script to cleanly remove printers (but keeps drivers for reuse)  
✅ **Typo Fixes** - Fixed "aleady" → "already" and other minor issues  

## Components

- **Deploy_Printer.ps1** - Installation script
- **Detect_Printer.ps1** - Detection script for Intune compliance
- **Uninstall_Printer.ps1** - Uninstallation script (NEW in V2)
- **PCL 6 Printer Drivers** - Your printer driver package
- **Intune Win32 App** - Package created with IntuneWinAppUtil.exe

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or higher
- Microsoft Endpoint Manager (Intune)
- PCL 6 Compatible Printer Drivers (tested with Canon)
- Network printer with TCP/IP connectivity

## Variables and Files Needed for Deployment

All scripts use the same parameters for consistency:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `PrinterName` | Display name for the printer | `Canon imageRUNNER (Sonitlo Managed)` |
| `PrinterDriverModelName` | Exact driver name from INF file | `Canon Generic Plus PCL6` |
| `PrinterDriverZipFileName` | Name of the zipped driver package | `Driver.ZIP` |
| `PrinterDriverModelFileName` | INF file name inside the ZIP | `CNP60MA64.INF` |
| `PrinterPortIPAddress` | IP address of the printer | `192.168.1.150` |
| `PrinterPortName` | Name for the TCP/IP port | `192.168.1.150` |
| `PrinterPortNumber` | TCP/IP port number (optional) | `9100` (default) |
| `SNMPCommunity` | SNMP community string (optional) | `public` (default) |
| `EnableSNMP` | Enable SNMP for printer (optional) | `$true` (default) |

## Step-by-Step Deployment Guide

### Step 1: Prepare the Driver Files

1. Download the **PCL 6 driver** for your printer from the manufacturer's website
2. Extract the installer and locate the **Driver** folder containing the INF file
3. Note the exact INF filename (e.g., `CNP60MA64.INF`)
4. Compress the entire **Driver** folder into a ZIP file named `Driver.ZIP`

**Example folder structure inside Driver.ZIP:**
```
Driver/
├── CNP60MA64.INF
├── CNP60M.DAT
├── CNP60M.DLL
└── [other driver files]
```

### Step 2: Update Deploy_Printer.ps1

Edit the parameter values at the top of the script:

```powershell
param
(
    [String] $PrinterPortIPAddress = "192.168.1.150",
    [String] $PrinterPortName = "192.168.1.150",
    [String] $PrinterName = "Canon imageRUNNER (Sonitlo Managed)",
    [String] $PrinterDriverModelName = "Canon Generic Plus PCL6",
    [String] $PrinterDriverZipFileName = "Driver.ZIP",
    [String] $PrinterDriverModelFileName = "CNP60MA64.INF"
)
```

### Step 3: Update Detect_Printer.ps1

Use the **exact same values** as Deploy_Printer.ps1:

```powershell
param
(
    [String] $PrinterPortIPAddress = "192.168.1.150",
    [String] $PrinterPortName = "192.168.1.150",
    [String] $PrinterName = "Canon imageRUNNER (Sonitlo Managed)",
    [String] $PrinterDriverModelName = "Canon Generic Plus PCL6"
)
```

### Step 4: Create the Win32 App Package

1. Place `Deploy_Printer.ps1` and `Driver.ZIP` in the same folder
2. Download [IntuneWinAppUtil.exe](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) if you don't have it
3. Run the utility:
   ```
   IntuneWinAppUtil.exe -c "C:\Source" -s "Deploy_Printer.ps1" -o "C:\Output"
   ```

### Step 5: Upload to Intune

1. Go to **Microsoft Endpoint Manager admin center**
2. Navigate to **Apps** > **Windows** > **Add**
3. Select **Windows app (Win32)**
4. Upload the `.intunewin` file

**Program Configuration:**
- **Install command:** 
  ```
  %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File Deploy_Printer.ps1
  ```
- **Uninstall command:** 
  ```
  %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File Uninstall_Printer.ps1
  ```

**Requirements:**
- Operating System: Windows 10 1607+ or Windows 11

**Detection Rules:**
- Use a custom detection script
- Upload `Detect_Printer.ps1`

**Assignment:**
- Assign to user or device groups as required

## Copy-Paste Template for Intune App Description

Intune's description field supports markdown. Copy the markdown template below and paste it directly into the Description field.

<details>
<summary><b>Click here to expand the markdown template</b></summary>

```markdown
## 📄 PRINTER DEPLOYMENT CONFIGURATION

**Printer Name:** Canon imageRUNNER (Sonitlo Managed)  
**Printer IP Address:** 192.168.1.150  
**Port Name:** 192.168.1.150  
**Port Number:** 9100  
**Driver Model:** Canon Generic Plus PCL6  
**Driver INF File:** CNP60MA64.INF  
**SNMP Enabled:** Yes (Community: public)  
**Script Version:** V2  

---

## 📋 INSTALLATION DETAILS

**Install Command:**  
```
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File Deploy_Printer.ps1
```

**Uninstall Command:**  
```
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File Uninstall_Printer.ps1
```

**Detection Method:** Custom Script (Detect_Printer.ps1)  
**Log Location:** C:\ProgramData\PrinterDeployment\

---

## ⚙️ FEATURES

- Automatic driver installation using pnputil and native PowerShell cmdlets
- TCP/IP port configuration with SNMP support
- Comprehensive logging for troubleshooting
- Clean uninstallation (preserves driver for reuse)
- Special character support in printer names

*Deployed using V2 scripts - Modern PowerShell implementation*
```

</details>

**Instructions:**
1. Click the expandable section above
2. Copy the entire markdown code (use the copy button)
3. Paste into Intune's **Description** field
4. Update the configuration values to match your printer
5. The markdown will render with proper formatting in Intune

## Uninstalling Printers (V2 Feature)

### Step 6: Update Uninstall_Printer.ps1 (Optional)

If you want to use the uninstall functionality:

1. Update `Uninstall_Printer.ps1` with the same parameters
2. Place it in the same folder as `Deploy_Printer.ps1` before creating the `.intunewin` package
3. Set `RemovePort` to `$false` if you want to keep the port for reuse

The uninstall script will:
- Remove the printer instance
- Optionally remove the TCP/IP port (if not used by other printers)
- **Keep the driver installed** (drivers may be used by multiple printers)

## Logging and Troubleshooting

All scripts log to: `C:\ProgramData\PrinterDeployment\`

**Log files:**
- `Deploy_YYYYMMDD_HHMMSS.log` - Installation logs
- `Detect_YYYYMMDD_HHMMSS.log` - Detection logs
- `Uninstall_YYYYMMDD_HHMMSS.log` - Uninstallation logs

**Common issues and solutions:**

| Issue | Cause | Solution |
|-------|-------|----------|
| Driver installation fails | Wrong INF file specified | Check the exact filename in Driver.ZIP |
| Port already exists | Previous installation | Script will reuse existing port (safe) |
| Detection fails after install | Parameter mismatch | Ensure both scripts have identical parameters |
| Locale error (V1 only) | Non-English Windows | Use V2 scripts with PowerShell cmdlets |

## Advanced Configuration

### Custom Port Number

If your printer uses a non-standard port:

```powershell
[Int] $PrinterPortNumber = 9101  # Change from default 9100
```

### Disable SNMP

If SNMP causes issues with your printer:

```powershell
[Bool] $EnableSNMP = $false
```

### Keep Port on Uninstall

To preserve the port for future use:

```powershell
[Bool] $RemovePort = $false
```

## End User Experience

### Installation Notification
If notifications are enabled in Intune, users will see a toast notification when the printer is installed.

### Printer Availability
The printer will appear in:
- **Settings** > **Bluetooth & devices** > **Printers & scanners** (Windows 11)
- **Settings** > **Devices** > **Printers & scanners** (Windows 10)
- Control Panel > Devices and Printers

### Print Dialog
Users can select the newly installed printer from any application's print dialog.

## Testing Recommendations

Before deploying to production:

1. **Test in a lab environment** with a representative device
2. **Check logs** in `C:\ProgramData\PrinterDeployment\` for any warnings
3. **Verify detection** by running `Detect_Printer.ps1` manually
4. **Test printing** from multiple applications (Notepad, Word, PDF viewer)
5. **Test uninstall** to ensure clean removal

## Migration from V1 to V2

To upgrade existing deployments:

1. Create a new Win32 app in Intune using V2 scripts
2. Assign to the same groups as your V1 deployment
3. The V2 scripts will detect and skip reinstallation if V1 is present
4. Optionally supersede the V1 app with the V2 app in Intune

**Note:** V2 is fully backward compatible. If a printer was installed with V1, V2 detection will recognize it correctly.

## Tested Configurations

✅ Canon imageRUNNER ADVANCE series with Generic Plus PCL6 driver  
✅ Windows 10 21H2, 22H2  
✅ Windows 11 21H2, 22H2, 23H2  
✅ English, French, German, Spanish Windows editions  
✅ Both User and System context installations  

## Support and Contributions

For issues or suggestions, please refer to the main repository.

## License

This script is provided as-is for use with Microsoft Endpoint Manager deployments.

---

**Version:** 2.0  
**Last Updated:** February 2026  
**Author:** Madhu Perera

Good Luck! 🎉
