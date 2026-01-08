# Baseline Registry Keys Detection and Remediation Scripts

## Overview

These baseline scripts provide a reusable template for managing registry keys and values through Intune Proactive Remediations. The scripts are designed to:

- **Detect** if registry keys exist and have the correct values
- **Remediate** by creating or updating registry keys to match expected configuration
- Provide detailed logging and status information
- Follow Intune Proactive Remediation exit code standards

## Files

### Detect-RegistryKeys.ps1
Detection script that checks if registry keys match expected values.

**Exit Codes:**
- `0` - All registry keys are compliant
- `1` - One or more registry keys are missing or have incorrect values (triggers remediation)

### Remediate-RegistryKeys.ps1
Remediation script that creates or updates registry keys to match expected configuration.

**Exit Codes:**
- `0` - All registry keys successfully remediated
- `1` - Remediation failed

## Configuration

Both scripts use the same configuration format for registry keys. You **MUST** keep the configurations in sync between both scripts.

### Registry Key Configuration Format

```powershell
$RegistryKeysToCheck = @(
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        ValueName    = 'EnableActivityFeed'
        ExpectedData = 0
        ValueType    = 'DWord'
        Description  = 'Disable Activity Feed'
    },
    @{
        Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        ValueName    = 'TaskbarAl'
        ExpectedData = 0
        ValueType    = 'DWord'
        Description  = 'Set Taskbar to Left Alignment'
    }
    # Add more entries as needed
)
```

### Configuration Properties

| Property | Required | Description | Example |
|----------|----------|-------------|---------|
| **Path** | Yes | Full registry path (use PowerShell format) | `HKLM:\SOFTWARE\Policies\...` |
| **ValueName** | Yes | Name of the registry value | `EnableActivityFeed` |
| **ExpectedData** | Yes | Expected value data | `0`, `1`, `"StringValue"` |
| **ValueType** | Yes | Registry value type | `DWord`, `String`, `QWord`, etc. |
| **Description** | No | Human-readable description | `Disable Activity Feed` |

### Supported Value Types

- `String` - Text value
- `ExpandString` - Expandable string (environment variables)
- `Binary` - Binary data
- `DWord` - 32-bit number (0-4294967295)
- `QWord` - 64-bit number
- `MultiString` - Array of strings

### Registry Hive Abbreviations

- `HKLM:` = `HKEY_LOCAL_MACHINE`
- `HKCU:` = `HKEY_CURRENT_USER`
- `HKCR:` = `HKEY_CLASSES_ROOT`
- `HKU:` = `HKEY_USERS`
- `HKCC:` = `HKEY_CURRENT_CONFIG`

## Usage Examples

### Example 1: Disable Windows Timeline Features

```powershell
$RegistryKeysToCheck = @(
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        ValueName    = 'EnableActivityFeed'
        ExpectedData = 0
        ValueType    = 'DWord'
        Description  = 'Disable Activity Feed'
    },
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        ValueName    = 'PublishUserActivities'
        ExpectedData = 0
        ValueType    = 'DWord'
        Description  = 'Disable Publishing User Activities'
    },
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        ValueName    = 'UploadUserActivities'
        ExpectedData = 0
        ValueType    = 'DWord'
        Description  = 'Disable Uploading User Activities'
    }
)
```

### Example 2: Configure Windows 11 Taskbar Alignment

```powershell
$RegistryKeysToCheck = @(
    @{
        Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        ValueName    = 'TaskbarAl'
        ExpectedData = 0
        ValueType    = 'DWord'
        Description  = 'Set Windows 11 Taskbar to Left Alignment (0=Left, 1=Center)'
    }
)
```

### Example 3: Configure Edge Browser Settings

```powershell
$RegistryKeysToCheck = @(
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        ValueName    = 'HideFirstRunExperience'
        ExpectedData = 1
        ValueType    = 'DWord'
        Description  = 'Hide Edge First Run Experience'
    },
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        ValueName    = 'DefaultBrowserSettingEnabled'
        ExpectedData = 0
        ValueType    = 'DWord'
        Description  = 'Disable Default Browser Prompt'
    },
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        ValueName    = 'HomepageLocation'
        ExpectedData = 'https://www.example.com'
        ValueType    = 'String'
        Description  = 'Set Edge Homepage'
    }
)
```

### Example 4: Disable Consumer Features in Windows

```powershell
$RegistryKeysToCheck = @(
    @{
        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        ValueName    = 'DisableWindowsConsumerFeatures'
        ExpectedData = 1
        ValueType    = 'DWord'
        Description  = 'Disable Windows Consumer Features'
    }
)
```

## Deployment in Intune

### Creating a Proactive Remediation Package

1. **Navigate to Intune Portal**
   - Go to: Devices > Scripts and remediations > Proactive remediations

2. **Create New Package**
   - Click "Create script package"
   - Name: `Registry Configuration - [Your Use Case]`
   - Description: Describe what registry keys are being managed

3. **Upload Scripts**
   - Detection script: `Detect-RegistryKeys.ps1`
   - Remediation script: `Remediate-RegistryKeys.ps1`

4. **Configure Settings**
   - Run this script using logged-on credentials: **No** (for HKLM) or **Yes** (for HKCU)
   - Enforce script signature check: As per your policy
   - Run script in 64-bit PowerShell: **Yes** (recommended)

5. **Assign to Groups**
   - Select target device or user groups
   - Set schedule (daily, hourly, etc.)

### Important Deployment Considerations

#### HKLM vs HKCU
- **HKLM (Local Machine)**: Run script in **SYSTEM** context
  - Select: "Run this script using logged-on credentials: **No**"
  
- **HKCU (Current User)**: Run script in **USER** context
  - Select: "Run this script using logged-on credentials: **Yes**"

#### Mixed Registry Hives
If you need to manage both HKLM and HKCU keys:
- Create **two separate** Proactive Remediation packages
- One for HKLM keys (run as system)
- One for HKCU keys (run as user)

## Testing Scripts Locally

### Test Detection Script
```powershell
# Run as Administrator (for HKLM) or as User (for HKCU)
.\Detect-RegistryKeys.ps1

# Check exit code
$LASTEXITCODE
# 0 = Compliant
# 1 = Non-compliant
```

### Test Remediation Script
```powershell
# Run as Administrator (for HKLM) or as User (for HKCU)
.\Remediate-RegistryKeys.ps1

# Check exit code
$LASTEXITCODE
# 0 = Success
# 1 = Failed
```

### Full Test Cycle
```powershell
# 1. Run detection (should show non-compliant if keys don't exist)
.\Detect-RegistryKeys.ps1

# 2. Run remediation (should create/update keys)
.\Remediate-RegistryKeys.ps1

# 3. Run detection again (should show compliant)
.\Detect-RegistryKeys.ps1
```

## Customization Guide

### Step 1: Copy the Baseline Scripts
Create a new folder for your specific use case:
```
Proactive_Remediations\
  └── YourCustomName\
      ├── Detect-RegistryKeys.ps1
      └── Remediate-RegistryKeys.ps1
```

### Step 2: Update Configuration
Edit both scripts and update the `$RegistryKeysToCheck` array with your specific registry keys.

### Step 3: Test Locally
Always test scripts locally before deploying to production.

### Step 4: Deploy to Test Group
Deploy to a small test group first to validate behavior.

### Step 5: Production Deployment
After successful testing, deploy to production groups.

## Troubleshooting

### Detection Always Shows Non-Compliant
- Verify registry path format (use PowerShell format: `HKLM:\` not `HKEY_LOCAL_MACHINE\`)
- Check data type matches (DWord vs String)
- Ensure expected data matches exactly (case-sensitive for strings)
- Verify script is running in correct context (user vs system)

### Remediation Fails
- Check permissions (HKLM requires admin/system)
- Verify ValueType is correct
- Check for typos in registry path
- Review Intune logs for detailed error messages

### Registry Changes Don't Persist
- Some registry keys require a restart or logoff/logon
- Group Policy may be overriding settings
- Check if another policy or script is reverting changes

### Viewing Intune Logs
1. Device logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`
2. Use CMTrace or similar log viewer
3. Look for your script package name

## Best Practices

1. **Always Keep Scripts in Sync**
   - Detection and remediation must have identical registry configurations

2. **Use Descriptive Names**
   - Name your Proactive Remediation package clearly
   - Use good descriptions for each registry key

3. **Test Thoroughly**
   - Test on local machine first
   - Deploy to test group before production
   - Verify on different Windows versions if applicable

4. **Document Your Changes**
   - Keep notes on why each registry key is being set
   - Document the expected impact

5. **Monitor Compliance**
   - Review Proactive Remediation reports in Intune
   - Track success/failure rates
   - Investigate persistent failures

6. **Version Control**
   - Keep scripts in source control (Git)
   - Track changes over time
   - Document updates in commit messages

## Related Resources

- [Microsoft Intune Proactive Remediations Documentation](https://learn.microsoft.com/en-us/mem/intune/fundamentals/remediations)
- [PowerShell Registry Provider](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_registry_provider)
- [Windows Registry Data Types](https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-value-types)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-08 | Initial baseline scripts created |

## Author

Madhu Perera

## License

Use and modify as needed for your organization.
