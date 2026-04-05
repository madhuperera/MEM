# L2TP VPN Cleanup — Proactive Remediation

Detects and removes **all L2TP VPN connections** from Windows devices via Intune Proactive Remediations.

## Why Two Sets?

Windows stores VPN connections in two separate phonebooks:

| Phonebook | Created With | Visible To | Requires |
|-----------|-------------|------------|----------|
| **System** (all-user) | `-AllUserConnection` flag | All users on the device | SYSTEM context |
| **User** (per-user) | No flag (default) | Only the creating user | User context |

A single script running as SYSTEM **cannot see or remove** user-level VPNs, and vice versa. You need both to fully clean up.

## Structure

```
L2TP_VPN_Cleanup/
├── System/
│   ├── Detect-L2TPVPN.ps1      # Checks system phonebook for L2TP VPNs
│   └── Remediate-L2TPVPN.ps1   # Removes L2TP VPNs from system phonebook
└── User/
    ├── Detect-L2TPVPN.ps1      # Checks user phonebook for L2TP VPNs
    └── Remediate-L2TPVPN.ps1   # Removes L2TP VPNs from user phonebook
```

## Intune Deployment

Create **two** Proactive Remediation packages in Intune:

### Package 1: L2TP VPN Cleanup — System

| Setting | Value |
|---------|-------|
| Detection script | `System\Detect-L2TPVPN.ps1` |
| Remediation script | `System\Remediate-L2TPVPN.ps1` |
| Run this script using the logged-on credentials | **No** |
| Run script in 64-bit PowerShell | **Yes** |

### Package 2: L2TP VPN Cleanup — User

| Setting | Value |
|---------|-------|
| Detection script | `User\Detect-L2TPVPN.ps1` |
| Remediation script | `User\Remediate-L2TPVPN.ps1` |
| Run this script using the logged-on credentials | **Yes** |
| Run script in 64-bit PowerShell | **Yes** |

## Behaviour

- **Detection**: Enumerates VPN connections and filters by `TunnelType -eq "L2tp"`. Returns exit 0 (compliant) if none found, exit 1 (non-compliant) if any exist.
- **Remediation**: Disconnects any active L2TP VPN first (`rasdial /DISCONNECT`), then removes it with `Remove-VpnConnection -Force`.
