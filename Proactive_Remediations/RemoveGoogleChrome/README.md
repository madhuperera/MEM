# Remove Google Chrome — Proactive Remediation

Detects and removes **Google Chrome** from Windows devices via Intune Proactive Remediations.

## Why Two Sets?

Chrome can be installed two different ways:

| Install type | Created With | Registry | Visible To | Requires |
|---|---|---|---|---|
| **Machine-wide** | Enterprise MSI / admin install | `HKLM\...\Uninstall` | All users on the device | SYSTEM context |
| **Per-user** | Standalone installer (no admin rights) | `HKCU\...\Uninstall` | Only the installing user | User context |

A script running as SYSTEM **cannot see or remove** a per-user install (it lives under that user's profile), and a script running as the user cannot see or remove a machine-wide install (it needs elevation). You need both packages to fully clean up a device — Chrome could be present via either path, or both at once.

## Structure

```
RemoveGoogleChrome/
├── System/
│   ├── Detect-GoogleChrome.ps1      # Checks HKLM + Program Files for a machine-wide install
│   └── Remediate-GoogleChrome.ps1   # Removes the machine-wide install
└── User/
    ├── Detect-GoogleChrome.ps1      # Checks HKCU + %LocalAppData% for a per-user install
    └── Remediate-GoogleChrome.ps1   # Removes the per-user install
```

## Intune Deployment

Create **two** Proactive Remediation packages in Intune:

### Package 1: Remove Google Chrome — System

| Setting | Value |
|---|---|
| Detection script | `System\Detect-GoogleChrome.ps1` |
| Remediation script | `System\Remediate-GoogleChrome.ps1` |
| Run this script using the logged-on credentials | **No** |
| Run script in 64-bit PowerShell | **Yes** |

### Package 2: Remove Google Chrome — User

| Setting | Value |
|---|---|
| Detection script | `User\Detect-GoogleChrome.ps1` |
| Remediation script | `User\Remediate-GoogleChrome.ps1` |
| Run this script using the logged-on credentials | **Yes** |
| Run script in 64-bit PowerShell | **Yes** |

Both packages are independent and idempotent — assign them to the same device group; the order between them doesn't matter.

## Behaviour

- **Detection**: checks the relevant uninstall registry key (`HKLM` for System, `HKCU` for User) for a `DisplayName` matching `Google Chrome*`, and cross-checks for `chrome.exe` on disk in case registry and disk state disagree. Exit 0 = compliant (not found), exit 1 = non-compliant (found).
- **Remediation**:
  1. Stops running `chrome.exe` / `GoogleCrashHandler(64).exe` processes.
  2. Runs Chrome's own silent uninstaller using the `UninstallString` recorded in the registry (not hardcoded — Chrome's install path includes a version number that changes with every update), with `--force-uninstall` appended to suppress prompts.
  3. Removes any leftover install directory and Start Menu / Desktop shortcuts.
  4. **Guarded Google Update cleanup**: Google Update (`GoogleUpdate.exe`, its services `gupdate`/`gupdatem`, and its scheduled tasks) is a **shared updater** also used by other Google software (e.g. Google Drive, Google Earth). It is only removed if no other Google-published application (`Publisher = "Google LLC"`) remains installed in that context — otherwise it's left in place and the skip is logged, so unrelated Google apps keep updating normally.
  5. Re-verifies Chrome is actually gone before reporting success.

### ⚠️ This is a full wipe

The **User** remediation script deletes the entire per-user Chrome folder, which includes `User Data` — bookmarks, saved passwords, browsing history, and installed extensions. This is deliberate (not a bug): the goal is full removal, not preserve-and-uninstall. Browsing data is **not recoverable** once this script runs. Communicate this to end users before assigning the remediation broadly.

### ⚠️ Reinstall loops

If Chrome is being pushed to the same devices via an Intune Win32 app, Group Policy software install, or Chrome Enterprise policy, this remediation will fight that deployment — detect non-compliant → remove → reinstalled by policy → detect non-compliant again. Confirm no such deployment targets the same device group before enabling this remediation.

### Known cosmetic side effect

If Chrome was pinned to the taskbar, the pinned icon may be left behind as a broken tile after removal — Windows doesn't always clean these up automatically. This is not a script defect.
