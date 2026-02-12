# Secure Boot 2023 Certificate Check - Custom Compliance Policy

## Overview

This custom compliance policy for Microsoft Intune monitors devices for the presence and version of Secure Boot certificates, specifically focusing on the Windows UEFI CA 2023 certificates. Devices must have the updated 2023 Secure Boot certificates in both the KEK (Key Exchange Key) and DB (Database) to be considered compliant.

## Background

Microsoft released updated Secure Boot certificates in 2023 to address security vulnerabilities in older certificates. These updated certificates are critical for maintaining the security posture of Windows devices using UEFI Secure Boot.

### Why This Matters

- **Security**: The 2023 certificates address known vulnerabilities in earlier certificate versions
- **Compatibility**: Ensures devices can boot properly with the latest security updates
- **Compliance**: Organizations may require the 2023 certificates as part of their security baseline
- **Revocation Events**: Older certificates may be subject to revocation, potentially causing boot failures

## Files in This Folder

| File | Description |
|------|-------------|
| `Detect-SecureBootCert2023Compliance.ps1` | PowerShell detection script that checks Secure Boot certificate versions |
| `Required.json` | Intune Custom Compliance Policy JSON definition with compliance rules |
| `README.md` | This documentation file |

## How It Works

This solution uses Intune's **Custom Compliance Policy** feature, which consists of:

1. **Detection Script** (`Detect-SecureBootCert2023Compliance.ps1`): Runs on client devices to extract and report Secure Boot certificate information
2. **Compliance Rules** (`Required.json`): Defines what values constitute compliance in JSON format

### Detection Script Functionality

The PowerShell script performs the following actions:

1. **Parses UEFI Variables**: Accesses raw UEFI Secure Boot variables using `Get-SecureBootUEFI`
2. **Extracts KEK Certificates**: Reads the Key Exchange Key database and identifies Microsoft KEK certificates
3. **Extracts DB Certificates**: Reads the Secure Boot Database and identifies Microsoft UEFI CA certificates
4. **Determines Certificate Versions**: Parses certificate subject names to extract the year (e.g., 2023)
5. **Checks for 2023 Certificate Presence**: Specifically verifies if "Windows UEFI CA 2023" exists in the database
6. **Returns JSON Output**: Provides structured data back to Intune for compliance evaluation

#### Script Output

The detection script returns a JSON object with three properties:

```json
{
  "SecureBootKEK": "2023",
  "SecureBootDB": "2023",
  "SecureBootDBHas2023": "true"
}
```

**Property Definitions:**

- `SecureBootKEK`: The year of the Microsoft KEK CA certificate (e.g., "2023", "2011", "unknown")
- `SecureBootDB`: The oldest year found among Microsoft UEFI CA certificates in the DB (e.g., "2023", "2011", "unknown")
- `SecureBootDBHas2023`: Boolean string indicating whether the Windows UEFI CA 2023 certificate is present ("true" or "false")

### Compliance Rules

The `Required.json` file defines three compliance rules:

#### Rule 1: SecureBootKEK Version
- **Requirement**: KEK certificate version must equal "2023"
- **Non-Compliance**: Devices with older KEK certificates (2011) or unknown values

#### Rule 2: SecureBootDB Version
- **Requirement**: DB certificate version must equal "2023"
- **Non-Compliance**: Devices with older DB certificates or unknown values

#### Rule 3: SecureBootDBHas2023 Presence
- **Requirement**: Windows UEFI CA 2023 certificate must be present in DB (value = "true")
- **Non-Compliance**: Devices missing the 2023 certificate in the Secure Boot Database

All rules include multi-language remediation strings (English and German) that inform end-users and administrators about non-compliance.

## Deployment Instructions

### Prerequisites

- Microsoft Intune tenant with appropriate licenses
- Devices must be:
  - Windows 10/11
  - UEFI-enabled (not legacy BIOS)
  - Enrolled in Intune
  - Have Secure Boot enabled

### Step 1: Create the Custom Compliance Policy

1. Sign in to the [Microsoft Intune admin center](https://intune.microsoft.com)
2. Navigate to **Devices** > **Compliance policies** > **Scripts**
3. Click **+ Add** > **Windows 10 and later**
4. Configure the policy:
   - **Name**: Secure Boot 2023 Certificate Check
   - **Description**: Validates presence of Windows UEFI CA 2023 Secure Boot certificates
   - **Detection script**: Upload `Detect-SecureBootCert2023Compliance.ps1`
   - **Rules file**: Upload `Required.json`
   - **Run script as 32-bit process**: No
5. Review and create

### Step 2: Assign the Policy

1. In the new compliance policy, navigate to **Assignments**
2. Select the device groups or users to target
3. Configure applicable scope tags if needed
4. Save the assignment

### Step 3: Monitor Compliance

1. Navigate to **Devices** > **Monitor** > **Compliance**
2. Review device compliance status
3. Check non-compliant devices for specific failures (KEK, DB, or 2023 certificate missing)

## Important Notes

- **Bitlocker Recovery**: Updating Secure Boot certificates may trigger BitLocker recovery on some devices. Plan accordingly and communicate with end users.
- **TPM Dependency**: Certificate updates interact with TPM measurements. Test thoroughly before broad deployment.
- **BIOS/UEFI Settings**: Some devices may require firmware updates from the manufacturer to support the 2023 certificates.
- **Virtual Machines**: VMs without proper UEFI configuration may report "unknown" or fail the check.

## Reference Articles & Further Reading

These articles provide additional context, detailed detection scripts, and remediation guidance:

### Patch My PC - Secure Boot Status Report
**URL**: https://patchmypc.com/blog/the-secure-boot-status-report-intune/

Comprehensive overview of Secure Boot certificate issues and how to create reporting in Intune. Includes:
- Background on the Secure Boot certificate updates
- Impact analysis for organizations
- Building custom reports in Intune

### T-bone's Original Detection Script
**URL**: https://github.com/Mr-Tbone/Intune/blob/master/Remedations/Detect-SecureBoot.ps1

The foundation for this detection script. T-bone's implementation includes:
- Complete Secure Boot certificate parsing logic
- EFI signature database structure handling
- X509 certificate extraction from UEFI variables

**Attribution**: This compliance policy's detection script is derived from T-bone's excellent work. The core certificate parsing functions are adapted from his original implementation.

### Call4Cloud - Device Certificate Renewal
**URL**: https://call4cloud.nl/intune-device-certificate-renewed-renewal/

Rudy Ooms' detailed analysis of device certificate renewal in Intune, covering:
- Certificate lifecycle management
- Renewal processes
- Troubleshooting certificate issues

### T-bone - Update Secure Boot Certificate Using Intune Remediation
**URL**: https://www.tbone.se/2026/01/09/update-secure-boot-certificate-by-using-intune-remediation/

Complete guide to remediating Secure Boot certificate issues using Intune Proactive Remediations:
- Full detection and remediation script examples
- Step-by-step deployment instructions
- BitLocker recovery considerations
- Real-world implementation experiences

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026 | Derived from @MrTbone_se | Initial implementation of custom compliance policy |

## Credits

- **Original Detection Logic**: [@MrTbone_se](https://github.com/Mr-Tbone) (T-bone Granheden)
- **Custom Compliance Implementation**: Adapted for Intune Custom Compliance Policy with JSON rules

## License

This compliance policy definition and detection script are provided as-is for use in Microsoft Intune environments. Please review and test thoroughly before production deployment.

## Contributing

Feedback and improvements are welcome. Please test any changes thoroughly in a lab environment before deploying to production devices.

---

**Last Updated**: February 2026  
**Intune Feature**: Custom Compliance Policies  
**Supported Platforms**: Windows 10/11 with UEFI Secure Boot
