# Windows Update Access

An **Intune Remediation** pair that detects devices where Windows Update has been
restricted by policy, and restores it. Three policy values are checked independently:

| Label | Value | Key |
|---|---|---|
| `WUAccess` | `DisableWindowsUpdateAccess` | `...\Windows\WindowsUpdate` |
| `WUInternet` | `DoNotConnectToWindowsUpdateInternetLocations` | `...\Windows\WindowsUpdate` |
| `NoAutoUpdate` | `NoAutoUpdate` | `...\Windows\WindowsUpdate\`**`AU`** |

All under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`. Each is a `REG_DWORD`
where **`1` = restricted** and **`0` = the documented default**. Remediation sets any that
are `1` back to `0`.

These are exactly the three values Microsoft names as **conflicting configurations** for
Windows Autopatch and Windows Update for Business
([reference](https://learn.microsoft.com/windows/deployment/windows-autopatch/references/windows-autopatch-conflicting-configurations)).

Built to the [script standard](../CLAUDE.md): both scripts emit a single flat JSON object
of scalar columns, so detection output imports with **Transform → Parse → JSON → expand →
tick every field**, one row per device.

---

## What each value does

### `DisableWindowsUpdateAccess`

"**Turn off access to all Windows Update features**" (`ICM.admx` → `RemoveWindowsUpdate_ICM`).
Computer Configuration → Administrative Templates → System → Internet Communication
Management → Internet Communication settings.

Set to `1`: all Windows Update features removed, automatic updating disabled, no critical
update notifications, and Device Manager stops pulling driver updates. Microsoft's
troubleshooting guidance for update error `0x8024002E` is exactly this remediation —
*"If the value is set to `1`, change it to `0`."*
([reference](https://learn.microsoft.com/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-update-error-code-0x8024002e))

> **Don't confuse it with `SetDisableUXWUAccess`**, which lives in the *same key* with the
> confusingly similar friendly name "Remove access to use all Windows update features"
> (`WindowsUpdate.admx`). That one only hides the *Check for updates* button while
> background scans and installs continue. Add it to `$S_TargetValues` if you want it too.

### `DoNotConnectToWindowsUpdateInternetLocations`

"**Do not connect to any Windows Update Internet locations**". Set to `1`, the device
cannot reach the public Windows Update service even for the metadata it needs, which can
also stop **Microsoft Store**, Windows Update client policies, and **Delivery
Optimization** working.

> This policy only takes effect when the device is pointed at an intranet update service
> via "Specify intranet Microsoft update service location". On a device with no WSUS
> configured the value may be present but inert — still worth clearing.

### `NoAutoUpdate` (in the `AU` subkey)

"**Configure Automatic Updates**" set to **Disabled** (`WindowsUpdate.admx` →
`AutoUpdateCfg`). `0` = Automatic Updates enabled (the documented default), `1` = disabled.

> **The `AU` subkey often does not exist** on a healthy device, and that is the correct
> state. Detection reports `NotPresent` (compliant) rather than treating a missing subkey
> as an error, and remediation will not create it unless you set `$S_CreateIfMissing`.

---

## Behaviour

Every target is evaluated independently — a device can be non-compliant on any one of the
three, and the report shows exactly which.

| Device state | `_State` | Compliant? | Remediation |
|---|---|---|---|
| Value is `1` | `NonCompliant` | No → exit 1 | **Sets it to `0`** and verifies. |
| Value is `0` | `Compliant` | Yes | None. |
| Value absent | `NotPresent` | Yes | None — see below. |
| Present, neither `0` nor `1` | `Unexpected` | Yes | None by default — see below. |
| Present but not a `DWord` | `TypeMismatch` | Yes | None by default. |
| Registry unreadable | `Unknown` | `Status = "Error"`, exit 0 | None. |

**An absent value is treated as compliant.** Not configured already allows updates, so
writing a `0` would create policy where the device had none. This matters most for
`NoAutoUpdate` — creating the `AU` subkey on a device that never had it is a change you
probably don't want. `$S_CreateIfMissing = $true` flips this.

**An unexpected value is reported but not touched.** A device with, say, `AUOptions`-style
data of `2` in one of these reports *Compliant* while updates may still be restricted — the
`UnexpectedCount` roll-up and `<Label>_Data` columns exist so those devices stay visible.
`$S_RemediateUnexpectedData = $true` rewrites any non-desired value to `0`.

**Failures are isolated.** If writing `NoAutoUpdate` fails but the other two succeed, the
result is `PartialSuccess` (exit 1) with per-target detail, not an all-or-nothing failure.

### Set to `0`, or remove the value?

This package **sets the values to `0`**. Microsoft's Autopatch conflicting-configurations
page instead **removes** them (`Remove-ItemProperty`), so the device falls back to having
no policy at all.

Both restore updates. Setting `0` is the more conservative, more auditable choice: the
value stays visible in the registry and in this report, so you can see the remediation
happened. Removing is cleaner if you want the device to look as though the policy was never
applied — which is what Autopatch onboarding wants.

**If you want removal instead**, use the [`_RegistryKeyCleanup`](../_RegistryKeyCleanup)
package, which deletes configured values rather than rewriting them. Point its
`$S_TargetValues` at these same three entries with `MatchData = $true` and `Data = 1`.

---

## Configuration

Edit the **CONFIG region at the top of both scripts**. Intune uploads them as two
independent files, so the block is duplicated — **keep them identical**.

| Variable | Default | Purpose |
|---|---|---|
| `$S_TargetValues` | the three entries above | Policy values to enforce. Each gets its own columns. |
| `$S_RemediateUnexpectedData` | `$false` | `$true` rewrites *any* present value that isn't `DesiredData`. |
| `$S_CreateIfMissing` | `$false` | `$true` creates the key and value when absent. |
| `$S_MaxDataLength` | `100` | Character cap for a single `_Data` column. |

Each `$S_TargetValues` entry:

| Key | Meaning |
|---|---|
| `Label` | Column-name prefix. **Keep it short** — it is repeated across five columns and the whole record must fit Intune's 2048-character limit. The full path and real value name are still reported in `<Label>_Path` and `<Label>_Name`, so a short label loses nothing. |
| `Path` / `Name` | The value to enforce. `-LiteralPath` is used, so no wildcard surprises. |
| `Type` | Expected kind, and the kind remediation writes. |
| `NonCompliantData` | The data that means "fix this" — `1`. |
| `DesiredData` | What remediation writes — `0`. |

---

## Output

### Detection

```json
{"ScriptType":"Detection","Solution":"WindowsUpdateAccess","ScriptVersion":"1.1","DeviceName":"RF-1234","UserName":"SYSTEM","RunContext":"System","CollectionTimeUtc":"2026-09-04T04:12:07Z","Status":"NonCompliant","TargetCount":3,"NeedsRemediation":2,"CompliantCount":1,"NotPresentCount":0,"UnexpectedCount":0,"WUAccess_Path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate","WUAccess_Name":"DisableWindowsUpdateAccess","WUAccess_Type":"DWord","WUAccess_Data":"1","WUAccess_State":"NonCompliant","WUInternet_Path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate","WUInternet_Name":"DoNotConnectToWindowsUpdateInternetLocations","WUInternet_Type":"DWord","WUInternet_Data":"0","WUInternet_State":"Compliant","NoAutoUpdate_Path":"HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU","NoAutoUpdate_Name":"NoAutoUpdate","NoAutoUpdate_Type":"DWord","NoAutoUpdate_Data":"1","NoAutoUpdate_State":"NonCompliant","Summary":"Windows Update is restricted by policy: 2 of 3 value(s) need remediation. ...","ErrorMessage":"","JsonLength":1108}
```

**31 columns**, ~1120 characters worst case (of 2048).

| Column | Description |
|---|---|
| `Status` | `Compliant` (exit 0), `NonCompliant` (exit 1), `Error` (exit 0). |
| `TargetCount` | Configured targets — `3`. Same on every device. |
| `NeedsRemediation` | Targets that will be written. Drives compliance. |
| `CompliantCount` / `NotPresentCount` / `UnexpectedCount` | Roll-ups by state. |
| `<Label>_Path` / `_Name` | The full key path and real value name being checked. |
| `<Label>_Type` / `_Data` | The kind and data **found on the device**. `""` if absent. |
| `<Label>_State` | Per the behaviour table above. |
| `JsonLength` | Record length; watch against the 2048-character limit if you add targets. |

### Remediation

**34 columns.** Same per-target shape, with `<Label>_Action` (`Set` / `Failed` /
`AlreadyCompliant` / `NotPresent` / `SkippedUnexpected` / `SkippedTypeMismatch` /
`NotAttempted`), `<Label>_DataWas` → `<Label>_DataNow`, and `<Label>_Error`. `Status` is
`Success` / `NoActionRequired` (exit 0) or `PartialSuccess` / `Failed` / `Error` (exit 1).

Every write is **verified by re-reading** both the data *and* the kind. A write that
returns without error but doesn't take is reported `Failed`, not a false success.

> Intune does not surface remediation STDOUT in the results export — only the detection
> script's. Remediation JSON goes to the local IME log (`AgentExecutor.log`). **Power BI
> reporting comes from the detection script.**

---

## Power BI / Excel import

1. **Get Data** → load the exported remediation results CSV.
2. Select the detection-output column → **Transform → Parse → JSON**.
3. Click **expand** (⇄) → **tick every field** → OK.
4. One row per device, with all three policy values as their own columns.

Useful filters:

- `NeedsRemediation > 0` — devices with Windows Update restricted.
- `NoAutoUpdate_State = "NonCompliant"` — devices with Automatic Updates specifically off.
- `UnexpectedCount > 0` — values holding something other than `0`/`1`; **not** remediated.
- `Status = "Error"` — devices that could not be assessed.

---

## Intune setup

1. **Intune admin center → Devices → Scripts and remediations → Create**.
2. **Detection script file:** `Detect-WindowsUpdateAccess.ps1`
3. **Remediation script file:** `Remediate-WindowsUpdateAccess.ps1`
4. Settings:
   - **Run this script using the logged-on credentials:** **No** — all three values are in
     HKLM and writing them needs SYSTEM.
   - **Enforce script signature check:** No (unless you sign them).
   - **Run script in 64-bit PowerShell:** **Yes**.
5. **Assign** to the target device group and set a schedule.

---

## Caveats

- **If a live policy is setting these values, remediation will not stick.** A Group Policy,
  or an Intune ADMX / settings-catalog policy, rewrites its registry values on every
  refresh. The device will flip back to `1`, be detected non-compliant, be remediated, and
  oscillate indefinitely. **Check the source before deploying** — `gpresult /h` on an
  affected device will tell you. If the value is policy-driven, remove or reconfigure the
  policy instead. This remediation is for values left behind by a retired GPO, an imaging
  script, a previous management tool, or manual tampering.
- **These three may not be the whole story.** Microsoft's guidance for turning Windows
  Update off also uses blank `WUServer` / `WUStatusServer` / `UpdateServiceUrlAlternate`
  and `UseWUServer` in the same key. If updates still fail after remediation, check those.
  Add them to `$S_TargetValues` if you need them covered.
- **Run in 64-bit PowerShell.** Running 32-bit silently redirects `HKLM:\SOFTWARE` to
  `HKLM:\SOFTWARE\WOW6432Node`, so the scripts would read and write the wrong hive.
- **A device with an `Unexpected` value reports as Compliant** under the default config.
  Filter on `UnexpectedCount > 0`, or set `$S_RemediateUnexpectedData = $true`.
- **Adding targets changes the column set**, and each costs ~120 characters. Check
  `JsonLength` after any config change — a record over 2048 characters is truncated to
  invalid JSON and Power BI silently drops that device's row.
- **Restoring Windows Update is a security-relevant change.** It's the right default for a
  managed fleet, but confirm no deliberate servicing strategy depends on updates being
  blocked on the targeted devices before assigning this broadly.
- **PowerShell version:** written for **Windows PowerShell 5.1**, the Intune Management
  Extension default.
