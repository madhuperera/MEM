# Registry Key Cleanup

An **Intune Remediation** pair that finds registry values (and optionally whole registry
keys) matching a configured spec and removes them. Use it to strip settings a previous
tool, GPO, or vendor installer left behind — where the goal is *absence*, not enforcement
of a value.

> Removing a value is not the same as setting it to `0`. Windows behaviour for an absent
> value is often "fall back to the application default", which is exactly what you want
> when retiring a policy — but confirm that for the setting you are targeting.

### Versions

| Version | Status | Notes |
|---|---|---|
| [`_v1/`](_v1) | **Frozen** — do not change | Original. Plain-text output, exit-code only. Detection stopped at the first match, ignored value types, and compared everything via `[int]` (which throws on non-numeric data). Remediation reported success without verifying the delete. |
| [`_v2/`](_v2) | **Current** | Rewritten to the [script standard](../CLAUDE.md). Type-aware comparison for every registry kind, `MatchData` toggle, whole-key removal, verified deletes, per-item failure isolation, and structured JSON output. |

v1 is kept only so a live Intune assignment still has its source in the repo. Deploy v2.

---

## What v2 changed, and why

| v1 behaviour | v2 behaviour |
|---|---|
| Output was a prose sentence — you learned *that* something was found, never *what* | Reports **path, value name, type and current data** for every configured target, as fixed scalar columns. Import is Parse JSON → expand → tick all fields. |
| A value present with unexpected data was invisible | Reported as `DataMismatch` / `TypeMismatch`, with its actual type and data. |
| `[int]$current -eq [int]$expected` | Type-aware comparison — `Binary` as hex, `MultiString` as `\|`-joined, `ExpandString` read raw. `[int]` cast threw on any non-numeric value in v1. |
| Value type declared in config but never checked | `Type` is compared when supplied, so a `String` named `bProtectedMode` is not mistaken for the `DWord` you meant. |
| Detection `break`s on the first match | Every target is evaluated, so the report shows *how many* and *which*. |
| `Get-ItemProperty` | `Get-Item` + `GetValueNames()` / `GetValueKind()` — distinguishes "absent" from "zero", and `-LiteralPath` stops `[`, `]`, `*` in key names being treated as wildcards. |
| Remediation reported success if the delete didn't throw | Re-reads the registry after each delete; a value still present is reported as a failure. |
| Remediation always exited `0`, even when every delete failed | Exit code reflects the real outcome. |
| No data comparison option | `MatchData = $false` removes a value whatever it holds. |
| Values only | `$S_TargetKeys` removes whole keys, recursively. |
| Free-text output | Single-line JSON — see [Output](#output). |

---

## Configuration

Edit the **CONFIG region at the top of both scripts**. Intune uploads detection and
remediation as two independent files with no shared state, so the block is duplicated —
**they must be kept identical** or remediation will act on a different set than detection
found.

| Variable | Purpose |
|---|---|
| `$S_SolutionName` | Identifier stamped into every JSON record. Leave as `RegistryKeyCleanup` unless you fork the package. |
| `$S_ScriptVersion` | Reported in every record so you can tell which version produced a row. |
| `$S_TargetValues` | The registry values to remove. Each entry produces its own columns. See below. |
| `$S_TargetKeys` | Whole keys to remove, recursively. Default empty. |
| `$S_MaxDataLength` | Character cap for a single `<Label>_Data` column, so one huge registry value cannot blow the size limit. |

### `$S_TargetValues` entries

```powershell
$S_TargetValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; Name = 'bProtectedMode'; Type = 'DWord'; Data = 1; MatchData = $true }
)
```

| Key | Required | Meaning |
|---|---|---|
| `Label` | No (defaults to `Name`) | Column-name prefix for this target's five output columns. Anything other than a letter or digit becomes `_`; duplicates are suffixed `_2`, `_3`. |
| `Path` | Yes | Full provider path (`HKLM:`, `HKCU:`, `HKU:`). Wildcards are **not** expanded. |
| `Name` | Yes | Value name. The **default value is not supported**. |
| `Type` | No | Expected kind: `DWord`, `QWord`, `String`, `ExpandString`, `MultiString`, `Binary`. Compared when present; **omit the key entirely** to skip the type check. |
| `Data` | When `MatchData` is `$true` | Expected data. Decimal for numeric kinds, `[byte[]]` for `Binary`, `[string[]]` for `MultiString`. |
| `MatchData` | No (default `$true`) | `$true` — remove **only** if current data equals `Data`. `$false` — remove whenever the value exists, whatever it holds. |

**A target is "in scope" only if it exists *and* passes the `Type` and `Data` comparisons.**
A value that is present but holds different data is deliberately left alone — it isn't what
this cleanup is scoped to remove. If you want it gone regardless, set `MatchData = $false`.

### `$S_TargetKeys`

```powershell
$S_TargetKeys = @(
    @{ Label = 'RetiredProduct'; Path = 'HKLM:\SOFTWARE\Policies\SomeVendor\RetiredProduct' }
)
```

**Each is removed recursively — the key, all its values, and every subkey beneath it.**
There is no data comparison guarding these, so scope them tightly. Default is empty. Each
entry contributes `<Label>_Path` and `<Label>_State` (`Present` / `NotPresent`) columns.

---

## Output

Both scripts emit a **single-line, flat JSON object** to STDOUT per the
[script standard](../CLAUDE.md). Every value is a scalar and the column set is fixed by the
configuration, so importing it is: **Transform → Parse → JSON → expand → tick every field**,
and you have a finished table with **one row per device**. No splitting, no second expand,
no row multiplication.

Each configured target contributes its own five columns, reporting the **path, value name,
type and data actually found on the device**, plus its state.

### Detection

```json
{"ScriptType":"Detection","Solution":"RegistryKeyCleanup","ScriptVersion":"2.0","DeviceName":"RF-1234","UserName":"JohnDoe","RunContext":"System","CollectionTimeUtc":"2026-08-05T04:12:07Z","Status":"NonCompliant","TargetValueCount":3,"TargetKeyCount":0,"InScopeCount":2,"MismatchCount":0,"NotPresentCount":1,"bProtectedMode_Path":"HKLM:\\SOFTWARE\\Policies\\Adobe\\Adobe Acrobat\\DC\\FeatureLockDown","bProtectedMode_Name":"bProtectedMode","bProtectedMode_Type":"DWord","bProtectedMode_Data":"1","bProtectedMode_State":"InScope","iProtectedView_Path":"HKLM:\\SOFTWARE\\Policies\\Adobe\\Adobe Acrobat\\DC\\FeatureLockDown","iProtectedView_Name":"iProtectedView","iProtectedView_Type":"DWord","iProtectedView_Data":"2","iProtectedView_State":"InScope","bEnableProtectedModeAppContainer_Path":"HKLM:\\SOFTWARE\\Policies\\Adobe\\Adobe Acrobat\\DC\\FeatureLockDown","bEnableProtectedModeAppContainer_Name":"bEnableProtectedModeAppContainer","bEnableProtectedModeAppContainer_Type":"","bEnableProtectedModeAppContainer_Data":"","bEnableProtectedModeAppContainer_State":"NotPresent","Summary":"2 registry target(s) in scope for removal; 0 present but not matching; 1 already clean.","ErrorMessage":"","JsonLength":1201}
```

#### Device-level columns

| Field | Description |
|---|---|
| `Status` | `Compliant` (exit 0), `NonCompliant` (exit 1), `Error` (exit 0). |
| `TargetValueCount` / `TargetKeyCount` | How many targets are **configured**. Same on every device. |
| `InScopeCount` | Targets present **and** matching — these will be removed. Drives compliance. |
| `MismatchCount` | Present but holding different data, or the wrong value kind. **Left alone.** |
| `NotPresentCount` | Already clean. |
| `JsonLength` | Length of this record. Watch it against the 2048 limit — see [Caveats](#caveats). |

#### Per-target columns — one set per configured target

| Column | Description |
|---|---|
| `<Label>_Path` | The configured key path. |
| `<Label>_Name` | The configured value name. |
| `<Label>_Type` | The value kind **found on the device** (`DWord`, `String`, …). `""` if absent. |
| `<Label>_Data` | The data **found on the device**, normalised to a string. `""` if absent. Binary as hex, MultiString `\|`-joined. Capped at `$S_MaxDataLength`. |
| `<Label>_State` | `InScope`, `DataMismatch`, `TypeMismatch`, `NotPresent`, or `Unknown` (target not reached because detection errored). |

`<Label>` defaults to the value name (`bProtectedMode_State`), or set `Label` in the config
entry to choose it. Whole-key targets get `<Label>_Path` and `<Label>_State`
(`Present` / `NotPresent`).

> **`Status = "Error"` exits 0 on purpose.** If the registry can't be read, compliance is
> *unknown*, not *bad* — Intune should not fire a remediation at a device that was never
> assessed. Those devices show as healthy in Intune's own column, so **filter on
> `Status = "Error"` in Power BI** to find them. Their per-target `_State` columns read
> `Unknown`, and the column set still matches every other device.

### Remediation

Mirrors the same per-target shape with `<Label>_Action`
(`Removed` / `Failed` / `NotPresent` / `SkippedMismatch` / `NotAttempted`) and
`<Label>_Error`, plus `InScopeCount`, `RemovedValueCount`, `RemovedKeyCount`, `FailedCount`.

`Status` is `Success` / `NoActionRequired` (exit 0), or `PartialSuccess` / `Failed` /
`Error` (exit 1). `NoActionRequired` is normal — detection and remediation are separate
runs, and something else (a GPO refresh, a user, another policy) may have removed the value
in between.

> **Intune does not surface remediation STDOUT in the results export** — only the detection
> script's output. This JSON is for the local IME log (`AgentExecutor.log`) and manual runs.
> **All Power BI reporting comes from `Detect-Keys.ps1`**, which is why the full per-target
> detail lives there.

---

## Power BI / Excel import

The data source is the **remediation results export** from Intune, which contains the
*Pre-remediation detection output* column.

1. **Get Data** → load the exported remediation results CSV.
2. Select the detection-output column → **Transform → Parse → JSON**. Each cell becomes a
   **Record**.
3. Click the **expand** (⇄) icon → **tick every field** → OK.
4. Done: a flat table, one row per device, with every targeted registry value's path, name,
   type, current data and state as its own column.

Useful filters:

- `InScopeCount > 0` — devices with values still to clean up.
- `MismatchCount > 0` — values that exist but hold something unexpected. Worth a look: they
  are **not** being removed.
- `Status = "Error"` — devices that could not be assessed at all.
- `<Label>_State` — per-setting rollout view across the estate.

Excel: **Data → Get Data → From JSON** (or Power Query as above), then expand — same result.

---

## Intune setup

1. **Intune admin center → Devices → Scripts and remediations → Create**.
2. **Detection script file:** `_v2/Detect-Keys.ps1`
3. **Remediation script file:** `_v2/Remediate-Keys.ps1`
4. Settings:
   - **Run this script using the logged-on credentials:** **No** for `HKLM:` targets.
     **Yes** if *any* target is under `HKCU:` — see the caveat below.
   - **Enforce script signature check:** No (unless you sign them).
   - **Run script in 64-bit PowerShell:** **Yes** — see the caveat below.
5. **Assign** to the target group and set a schedule.

---

## Caveats

- **Keep to about 7 value targets.** Intune stores only the first **2048 characters** of
  STDOUT, and **a truncated line is invalid JSON — Power BI drops that device's row
  entirely**, silently. Each value target costs roughly 220 characters (mostly the repeated
  key path), so the 3 defaults land near 1200. Check the `JsonLength` column after any
  config change; short key paths buy you more targets, long ones fewer. Split a large
  cleanup into two remediations rather than pushing past the limit.
- **Adding or removing a target changes the column set.** Existing rows in a Power BI model
  won't have the new columns, and a saved report referencing a removed column breaks.
  Refresh the query's field list after a config change.
- **Run in 64-bit PowerShell.** With the 64-bit setting off, the script runs 32-bit and
  Windows silently redirects `HKLM:\SOFTWARE` to `HKLM:\SOFTWARE\WOW6432Node`. You would be
  reading and deleting from a hive you didn't intend. To target the 32-bit hive, put
  `WOW6432Node` in the `Path` explicitly and still run 64-bit.
- **`HKCU:` under SYSTEM is the SYSTEM profile, not the user's.** Any `HKCU:` target
  requires *Run using logged-on credentials = Yes*, and then only remediates the user who
  happens to be signed in. For all users on a device, enumerate `HKU:` explicitly instead.
- **Keep the two config blocks in sync.** They are duplicated by necessity. If detection
  finds a target that remediation isn't configured for, the device loops non-compliant
  forever.
- **`$S_TargetKeys` is recursive and unguarded.** No data comparison protects it. Scope it
  to a leaf key you're certain about.
- **Deleting policy values changes behaviour.** Absent usually means "application default",
  which may be *less* restrictive than the value you removed. Confirm the setting's
  documented default before deploying.
- **PowerShell version:** written for **Windows PowerShell 5.1**, the Intune Management
  Extension default.
