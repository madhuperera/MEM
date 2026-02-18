# CrowdStrike Falcon Service Monitor - Custom Compliance Policy

## Overview

This custom compliance policy for Microsoft Intune monitors the CrowdStrike Falcon service (CSFalconService) status on Windows devices. Devices must have the CrowdStrike Falcon agent installed and the service running to be considered compliant.

## Background

CrowdStrike Falcon is a cloud-native endpoint protection platform that provides real-time threat detection and response capabilities. Ensuring the service is running is critical for maintaining endpoint security posture.

### Why This Matters

- **Security**: Active endpoint protection is essential for detecting and preventing threats
- **Compliance**: Many security frameworks require active endpoint detection and response (EDR) solutions
- **Visibility**: Quickly identify devices where protection may have been disabled or services stopped
- **Automation**: Proactively detect service failures before they lead to security incidents

## Files in This Folder

| File | Description |
|------|-------------|
| `Detect-CrowdStrikeFalconService.ps1` | PowerShell detection script that checks CrowdStrike Falcon service status |
| `Required.json` | Intune Custom Compliance Policy JSON definition with compliance rules |
| `README.md` | This documentation file |

## How It Works

This solution uses Intune's **Custom Compliance Policy** feature, which consists of:

1. **Detection Script** (`Detect-CrowdStrikeFalconService.ps1`): Runs on client devices to check service status
2. **Compliance Rules** (`Required.json`): Defines what values constitute compliance in JSON format

### Detection Script Functionality

The PowerShell script performs the following actions:

1. **Checks Service Existence**: Verifies if CSFalconService is installed on the device
2. **Monitors Service Status**: Determines if the service is running, stopped, or in another state
3. **Retry Logic**: If the service is not running, performs periodic checks every 30 seconds for up to 5 minutes
4. **Early Exit**: If service becomes running during the check period, reports success immediately
5. **Returns JSON Output**: Provides structured data back to Intune for compliance evaluation

#### Script Output

The detection script returns a JSON object with two properties:

```json
{
  "ServiceStatus": "Running",
  "ServiceExists": "true"
}
```

**Property Definitions:**

- `ServiceStatus`: Current status of the service - "Running", "Stopped", "NotInstalled", or "Error"
- `ServiceExists`: Boolean string indicating whether CSFalconService is installed ("true" or "false")

### Compliance Rules

The `Required.json` file defines two compliance rules:

#### Rule 1: Service Status
- **Requirement**: ServiceStatus must equal "Running"
- **Non-Compliance**: Devices where the service is stopped, disabled, or in any state other than running

#### Rule 2: Service Existence
- **Requirement**: ServiceExists must equal "true"
- **Non-Compliance**: Devices where CSFalconService is not installed

Both rules include multi-language remediation strings (English and German) that inform end-users and administrators about non-compliance.

## Deployment Instructions

### Prerequisites

- Microsoft Intune tenant with appropriate licenses
- Devices must be:
  - Windows 10/11
  - Enrolled in Intune
  - Have CrowdStrike Falcon agent installed (for compliant status)

### Step 1: Create the Custom Compliance Policy

1. Sign in to the [Microsoft Intune admin center](https://intune.microsoft.com)
2. Navigate to **Devices** > **Compliance policies** > **Scripts**
3. Click **+ Add** > **Windows 10 and later**
4. Configure the policy:
   - **Name**: CrowdStrike Falcon Service Monitor
   - **Description**: Validates CrowdStrike Falcon service is running on enrolled devices
   - **Detection script**: Upload `Detect-CrowdStrikeFalconService.ps1`
   - **Rules file**: Upload `Required.json`
   - **Run script as 32-bit process**: No
5. Review and create

### Step 2: Assign the Policy

1. Select the newly created policy
2. Click **Assignments**
3. Choose target groups (e.g., "All Devices" or specific security groups)
4. Review and save assignments

### Step 3: Monitor Compliance

1. Navigate to **Devices** > **Monitor** > **Device compliance**
2. View compliance status by policy
3. Click on the policy to see detailed per-device results
4. Non-compliant devices will show:
   - Service status (e.g., "Stopped" instead of "Running")
   - Remediation guidance from the JSON file

## Important Notes

### Detection Timing

- The script checks service status with a 5-minute retry window
- Checks are performed every 30 seconds during this window
- If the service starts during the check period, compliance is reported immediately
- This retry logic accommodates services that may start slowly after boot

### Service Name

- The script specifically looks for the service named **CSFalconService**
- This is the standard Windows service name for CrowdStrike Falcon
- Ensure your CrowdStrike deployment uses this service name

### Compliance Evaluation

- Custom compliance policies run on a schedule (typically every few hours)
- Allow time for initial policy deployment and evaluation
- Devices may show as "Not evaluated" initially until the script runs

### Remediation

This is a **detection-only** policy. To remediate non-compliant devices:

- Use Intune Win32 app deployment to install CrowdStrike Falcon
- Use PowerShell scripts or Proactive Remediations to start the service
- Investigate root causes of service failures (e.g., conflicts, crashes, manual disabling)

## Use Cases

### Scenario 1: Endpoint Protection Monitoring
Monitor all managed devices to ensure CrowdStrike protection is active and flag devices where it's stopped.

### Scenario 2: Conditional Access
Use compliance status as a gate for Conditional Access policies, preventing access from unprotected devices.

### Scenario 3: Security Posture Reporting
Generate reports showing which devices lack active endpoint protection.

### Scenario 4: Deployment Validation
After rolling out CrowdStrike Falcon, validate that the service is running on all targeted devices.

## Troubleshooting

### Devices Show "Not Installed"

- Verify CrowdStrike Falcon is deployed to the device
- Check if the service name is different from CSFalconService
- Confirm the agent installation completed successfully

### Devices Show "Stopped"

- Check Windows Event Logs for service startup failures
- Verify no Group Policy or other security software is blocking the service
- Investigate if users have manually stopped the service
- Consider deploying a Proactive Remediation to automatically start the service

### Script Returns "Error"

- Review script execution logs in Intune
- Check device permissions and PowerShell execution policy
- Verify script is not blocked by antivirus or application control

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | February 2026 | Madhu Perera | Initial implementation of CrowdStrike Falcon service monitoring |

## License

This compliance policy definition and detection script are provided as-is for use in Microsoft Intune environments. Please review and test thoroughly before production deployment.

## Contributing

Feedback and improvements are welcome. Please test any changes thoroughly in a lab environment before deploying to production devices.

---

**Last Updated**: February 2026  
**Intune Feature**: Custom Compliance Policies  
**Supported Platforms**: Windows 10/11  
**Service Monitored**: CSFalconService (CrowdStrike Falcon)
