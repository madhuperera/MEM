# Intune Proactive Remediation Script Standard

Rules for every PowerShell script in `Proactive_Remediations/`. Apply them to new scripts
without being asked. Existing scripts that predate this standard are only migrated when
explicitly requested — see [Versioning](#versioning).

---

## 1. Non-negotiables

1. **Exactly one line on STDOUT** — the standard JSON object, emitted once, as the last
   thing the script does before `exit`. Nothing else may write to STDOUT.
2. **Never use `Write-Host` or bare `Write-Output`** for progress, status, or debugging.
   Progress goes into the JSON (`ActionsTaken`) or to `Write-Verbose` (suppressed by
   default). A second STDOUT line breaks the Power BI / Excel JSON parse for that device.
3. **Never use `Write-Error`, `throw`, or let an exception escape.** The whole script body
   is wrapped in `try/catch`; the `catch` emits JSON with `Status = "Error"` and exits with
   the documented code.
4. **Windows PowerShell 5.1** is the target — the Intune Management Extension default.
   No PowerShell 7 syntax (`??`, `?.`, ternary, `-Parallel`).
5. **Save as UTF-8 (no BOM)** with CRLF line endings.
6. **Detection and remediation must be independently runnable.** Intune uploads them as two
   separate files with no shared state, so the config block and helper functions are
   duplicated verbatim in both. Changing one means changing the other — say so in a comment.

---

## 2. The JSON contract

A **single, flat, compact JSON object**. No nested objects. No arrays. No `null`. Absent
values are `""` (string) or `0` (number).

### The target workflow — design every script backwards from this

The reporting end goal is the Intune **remediation results CSV**, imported into Power BI or
Excel, where the user does exactly three things:

1. Select the detection-output column → **Transform → Parse → JSON**.
2. Click the **expand** (⇄) icon.
3. **Tick every field** and click OK.

That must yield a finished flat table, **one row per device**, with no further transforms.
Everything below follows from it:

- **A nested array or record breaks it.** The column shows as `List`/`Record` and needs a
  second expand, which multiplies one device into many rows.
- **A delimited composite breaks it.** `"a|b|c; d|e|f"` needs Split-by-delimiter into rows
  *then* into columns before it means anything.
- **A column set that varies by device breaks it.** Ticking every field on the first device
  produces `null` columns for devices that reported a different shape.

So: **every value is a scalar, and the column set is fixed by the script's configuration,
never by what happens to exist on the device.** `PersonalStorageReporting/Detect-PersonalStorageReport_v3.ps1`
is the reference implementation.

### Field order

Identity → status → solution-specific fields → free text. Free text goes **last** on
purpose: Intune stores only the first **2048 characters** of STDOUT, so if the line is
truncated the structured fields survive and only prose is lost.

### Envelope — always present, always these names

| Field | Type | Values |
|---|---|---|
| `ScriptType` | string | `Detection` or `Remediation` |
| `Solution` | string | Stable package identifier, e.g. `RegistryKeyCleanup`. Matches the folder name. |
| `ScriptVersion` | string | Version of *this script*, e.g. `2.0`. Bump on any behaviour change. |
| `DeviceName` | string | `$env:COMPUTERNAME` |
| `UserName` | string | `$env:USERNAME` |
| `RunContext` | string | `System`, `User`, or `Unknown` — detected at runtime from the token SID, never assumed. |
| `CollectionTimeUtc` | string | ISO 8601 UTC, `yyyy-MM-ddTHH:mm:ssZ` |
| `Status` | string | See the status tables below. |
| *…solution fields…* | | Inserted here. See §3. |
| `Summary` | string | One human-readable sentence. Always populated. |
| `ErrorMessage` | string | Exception text, or `""` when there was none. |

### Detection status and exit codes

| `Status` | Meaning | Exit | Intune behaviour |
|---|---|---|---|
| `Compliant` | Checked, nothing to do. | `0` | No remediation. |
| `NonCompliant` | Checked, action needed. | `1` | Runs the remediation script. |
| `Error` | **Could not determine compliance.** | `0` | No remediation. |

> `Error` exits **0** deliberately. An unreadable registry hive or an access-denied path
> means compliance is *unknown*, not *bad* — firing a remediation at a device we could not
> assess is worse than leaving it alone. The `Status` field is what makes the failure
> visible in reporting; filter on `Status = "Error"` in Power BI to find them. Do not
> filter on Intune's own detection column for this — an errored device shows as healthy
> there, which is the accepted cost of not remediating blind.

### Remediation status and exit codes

| `Status` | Meaning | Exit | Intune behaviour |
|---|---|---|---|
| `Success` | Everything actioned successfully. | `0` | Remediation succeeded. |
| `NoActionRequired` | Nothing in scope by the time it ran. | `0` | Remediation succeeded. |
| `PartialSuccess` | Some actions succeeded, some failed. | `1` | Remediation failed. |
| `Failed` | Nothing succeeded. | `1` | Remediation failed. |
| `Error` | Unhandled exception. | `1` | Remediation failed. |

> Remediation `Error` exits **1** — the opposite of detection. Detection failing means
> "unknown"; remediation failing means the device is still broken and must be reported.

### Example

```json
{"ScriptType":"Detection","Solution":"RegistryKeyCleanup","ScriptVersion":"2.0","DeviceName":"RF-1234","UserName":"JohnDoe","RunContext":"System","CollectionTimeUtc":"2026-08-05T04:12:07Z","Status":"NonCompliant","TargetValueCount":3,"TargetKeyCount":0,"InScopeCount":2,"MismatchCount":0,"NotPresentCount":1,"bProtectedMode_Path":"HKLM:\\SOFTWARE\\Policies\\Adobe\\Adobe Acrobat\\DC\\FeatureLockDown","bProtectedMode_Name":"bProtectedMode","bProtectedMode_Type":"DWord","bProtectedMode_Data":"1","bProtectedMode_State":"InScope","Summary":"2 registry target(s) in scope for removal; 0 present but not matching; 1 already clean.","ErrorMessage":"","JsonLength":1201}
```

---

## 3. Solution-specific fields

Insert between `Status` and `Summary`.

### Per-item detail: fixed columns, one set per configured item

This is the default pattern, and the one that makes "expand → tick all fields" work. When a
script reports on N things — registry values, folders, apps — give each one a stable
**Label** and emit **one fixed set of scalar columns per label**:

```
<Label>_Path   <Label>_Name   <Label>_Type   <Label>_Data   <Label>_State
```

- The label set comes from the **script's configuration**, so it is identical on every
  device. It must never be derived from what was found on the device.
- **Every column is emitted on every run**, whatever the outcome — pre-create them with
  empty/`Unknown` defaults *before* the `try` block so the `catch` path emits the same
  columns. A device that errored must still line up with the others.
- Labels must be unique and safe as column headers: strip to `[A-Za-z0-9_]`, and suffix
  duplicates `_2`, `_3` — two targets sharing a label silently overwrite each other in the
  ordered dictionary, losing a whole item from the report.
- Report the **actual state found on the device** (current type, current data), not the
  configured expectation. The expectation is already in the script; the export is only
  worth reading for what's actually out there.
- Pair with device-level roll-up counts (`InScopeCount`, `MismatchCount`, `NotPresentCount`)
  so you can filter without touching the per-item columns.

### Delimited strings: only for unbounded runtime discovery

When the item set genuinely **cannot** be known in advance — v3's `Other_FoldersFound`
discovers folder names that vary per device — collapse it into a single `; `-separated
string, capped with `Format-ListField`, paired with a count. Never a JSON array. Use this
only when fixed columns are impossible; a delimited string still needs splitting before
it's useful.

### General rules

- **PascalCase**, no spaces, no units in the value — units go in the name (`SizeMB`, not `Size`).
- **Booleans are `"Yes"` / `"No"` strings**, not JSON `true`/`false`, so column types stay uniform.
- **Numbers**: `[math]::Round($x, 2)` for anything fractional.
- **Cap any free-form value** (registry data, error text) so one huge item cannot blow the
  size limit.

### Size budget — 2048 characters, hard

Intune stores only the first **2048 characters** of STDOUT. **A truncated line is invalid
JSON, and Power BI drops that device's row entirely** — so this is a silent data-loss bug,
not a cosmetic one. Emit a **`JsonLength`** field as the last field so the real cost is
visible in the export itself, and state the practical item ceiling in the package README.
Rough budget: envelope ≈ 260, `Summary` ≈ 150, leaving ~1600 for per-item columns.

Remediation scripts mirror the same per-item columns with `<Label>_Action`
(`Removed` / `Failed` / `NotPresent` / `SkippedMismatch` / `NotAttempted`) and
`<Label>_Error`, plus roll-ups (`RemovedValueCount`, `FailedCount`).

> Intune does **not** surface remediation STDOUT in the results export — only the detection
> script's. Remediation JSON is for the local IME log (`AgentExecutor.log`) and manual runs.
> **All Power BI reporting must be driven from the detection script**, so put the reporting
> detail there even when the remediation script computes the same thing.

**Remediation must verify its own work** before reporting `Success` — re-check the thing it
changed. Never report success purely because a command returned without throwing.

---

## 4. Required script skeleton

Both script types follow this shape. The `#region` banners and `$S_` (script config) /
`$F_` (function-scope and working) prefixes match the existing repo convention.

```powershell
<#
.SYNOPSIS
    One line: what this script detects, or what it remediates.

.DESCRIPTION
    What it checks/does, how it decides, and any behaviour worth knowing before deploying.
    State the run context explicitly.

    Run Context: SYSTEM   (or: USER — required because ...)

.NOTES
    Author        : Madhu Perera
    Script Version: 2.0
    Requirements  : Windows 10/11, Windows PowerShell 5.1
    Output        : Single-line JSON object to STDOUT. See Proactive_Remediations/CLAUDE.md.
#>

#region ---------------------------- CONFIG ----------------------------------------

# MUST be identical to the matching Detect-/Remediate- script. Edit both together.

$S_SolutionName  = 'MySolution'
$S_ScriptVersion = '2.0'

# ... solution configuration ...

#endregion -------------------------------------------------------------------------


#region ---------------------------- FUNCTIONS -------------------------------------

function Write-IntuneResult
{
    <#
        Emits the standard single-line JSON object to STDOUT. Call EXACTLY ONCE, as the
        last action before exit. $F_Data is an [ordered] dictionary of solution fields,
        inserted between Status and Summary.
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Detection', 'Remediation')]
        [string]$F_ScriptType,

        [Parameter(Mandatory = $true)]
        [string]$F_Status,

        [System.Collections.Specialized.OrderedDictionary]$F_Data = ([ordered]@{}),

        [string]$F_Summary = '',

        [string]$F_ErrorMessage = ''
    )

    # This function is also called from the catch block, so it must never throw itself -
    # an emitter that fails leaves the device with no output at all. Casting to [string]
    # also turns an unexpectedly absent env var into "" rather than a JSON null.
    $F_RunContext = 'Unknown'
    try
    {
        $F_Sid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
        $F_RunContext = $(if ($F_Sid -eq 'S-1-5-18') { 'System' } else { 'User' })
    }
    catch
    {
        $F_RunContext = 'Unknown'
    }

    $F_Record = [ordered]@{
        ScriptType        = $F_ScriptType
        Solution          = $S_SolutionName
        ScriptVersion     = $S_ScriptVersion
        DeviceName        = [string]$env:COMPUTERNAME
        UserName          = [string]$env:USERNAME
        RunContext        = $F_RunContext
        CollectionTimeUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Status            = $F_Status
    }

    foreach ($F_Key in $F_Data.Keys) { $F_Record[$F_Key] = $F_Data[$F_Key] }

    $F_Record['Summary']      = $F_Summary
    $F_Record['ErrorMessage'] = $F_ErrorMessage

    # JsonLength is emitted so a config that has outgrown Intune's 2048-character STDOUT
    # limit is visible in the report instead of silently producing unparseable rows.
    $F_Json = ([pscustomobject]$F_Record) | ConvertTo-Json -Depth 3 -Compress
    $F_Record['JsonLength'] = $F_Json.Length + 20

    Write-Output (([pscustomobject]$F_Record) | ConvertTo-Json -Depth 3 -Compress)
}

function Get-TargetLabel
{
    <#
        Builds the fixed column-name prefix for a configured item: its Label, or a sensible
        fallback, reduced to letters, digits and underscores so it is safe as a Power BI
        column header. Pair with Resolve-UniqueLabel - two items sharing a label silently
        overwrite each other's columns.
    #>
    param([hashtable]$F_Target)

    $F_Label = ''
    if ($F_Target.ContainsKey('Label') -and -not [string]::IsNullOrWhiteSpace([string]$F_Target.Label))
    {
        $F_Label = [string]$F_Target.Label
    }
    elseif ($F_Target.ContainsKey('Name'))
    {
        $F_Label = [string]$F_Target.Name
    }

    $F_Label = ($F_Label -replace '[^A-Za-z0-9]', '_')
    if ([string]::IsNullOrWhiteSpace($F_Label)) { $F_Label = 'Target' }

    return $F_Label
}

function Resolve-UniqueLabel
{
    <# Guarantees label uniqueness by suffixing _2, _3 on collision. #>
    param
    (
        [string]$F_Label,
        [System.Collections.Generic.HashSet[string]]$F_Used
    )

    if ($F_Used.Add($F_Label)) { return $F_Label }

    $F_Suffix = 2
    while (-not $F_Used.Add("${F_Label}_$F_Suffix")) { $F_Suffix++ }

    return "${F_Label}_$F_Suffix"
}

# Only needed when the item set is discovered at runtime and cannot be fixed columns.
function Format-ListField
{
    <#
        Joins a list into a single '; '-separated string, capped at $F_MaxLength characters
        so the JSON stays inside Intune's 2048-character STDOUT limit. Whatever is dropped
        is reported as a '+N more' suffix rather than silently truncated.
    #>
    param
    (
        [string[]]$F_Items,
        [int]$F_MaxLength = 400
    )

    if (-not $F_Items -or $F_Items.Count -eq 0) { return '' }

    $F_Joined = ($F_Items -join '; ')
    if ($F_Joined.Length -le $F_MaxLength) { return $F_Joined }

    $F_Kept   = @()
    $F_Length = 0

    foreach ($F_Item in $F_Items)
    {
        $F_Next = $F_Length + $F_Item.Length + 2
        if ($F_Next -gt ($F_MaxLength - 20)) { break }
        $F_Kept  += $F_Item
        $F_Length = $F_Next
    }

    return (($F_Kept -join '; ') + "; +$($F_Items.Count - $F_Kept.Count) more")
}

#endregion -------------------------------------------------------------------------


#region ---------------------------- MAIN ------------------------------------------

$ErrorActionPreference = 'Stop'

# Device-level roll-ups.
$F_Data = [ordered]@{
    TargetCount     = @($S_Targets).Count
    InScopeCount    = 0
    NotPresentCount = 0
}

# EVERY per-item column is pre-created here, OUTSIDE the try block, with an empty/Unknown
# default. This is what guarantees the error path emits the same column set as a
# successful run, so every device lines up when you tick all fields in Power BI.
$F_UsedLabels = New-Object System.Collections.Generic.HashSet[string]
$F_Labels     = @()

foreach ($F_Target in $S_Targets)
{
    $F_Label = Resolve-UniqueLabel -F_Label (Get-TargetLabel -F_Target $F_Target) -F_Used $F_UsedLabels
    $F_Labels += $F_Label

    $F_Data["${F_Label}_Path"]  = [string]$F_Target.Path
    $F_Data["${F_Label}_State"] = 'Unknown'
}

try
{
    # Index-based loop so each item keeps the label allocated to it above.
    for ($F_Index = 0; $F_Index -lt @($S_Targets).Count; $F_Index++)
    {
        $F_Target = $S_Targets[$F_Index]
        $F_Label  = $F_Labels[$F_Index]

        # ... inspect the device, fill in $F_Data["${F_Label}_*"], emit nothing ...
    }

    Write-IntuneResult -F_ScriptType 'Detection' -F_Status $F_Status -F_Data $F_Data `
                       -F_Summary $F_Summary
    exit $F_ExitCode
}
catch
{
    # Detection: compliance is UNKNOWN, so exit 0 and do not trigger remediation.
    # Remediation: the device is still broken, so exit 1.
    # Items never reached keep their pre-initialised 'Unknown' state.
    Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'Error' -F_Data $F_Data `
                       -F_Summary 'Detection failed; compliance could not be determined.' `
                       -F_ErrorMessage $_.Exception.Message
    exit 0
}

#endregion -------------------------------------------------------------------------
```

**The `catch` block must be able to run, and must emit the full column set.** Build the
entire solution-field dictionary — roll-ups *and* every per-item column — before the `try`.
An error path that emits fewer columns produces ragged rows that break the expand.

---

## 5. Versioning

Scripts deployed to production are **frozen**. To change behaviour, add a version rather
than editing in place — a live Intune assignment points at an uploaded copy, and the repo
must still show what that copy does.

- Move the existing pair into a `_v1/` subfolder, unmodified.
- Create `_v2/` with the new scripts.
- The package `README.md` carries a version table stating which is current and what each
  version adds, following `PersonalStorageReporting/README.md`.
- Bump `$S_ScriptVersion` to match. It ships in every JSON record, so reports show exactly
  which version produced a row.

---

## 6. Folder layout

```
Proactive_Remediations/<SolutionName>/
├── README.md                 # required: purpose, config table, JSON schema, Intune setup
├── Detect-<Thing>.ps1
└── Remediate-<Thing>.ps1
```

- `Detect-` and `Remediate-` verb prefixes. `Remove-`, `Install-`, `Set-` are acceptable
  for the remediation half when the verb is more accurate.
- Split into `System/` and `User/` subfolders when a solution genuinely needs both contexts
  (see `RemoveGoogleChrome/`, `L2TP_VPN_Cleanup/`).
- Versioned packages use `_v1/` and `_v2/` subfolders, each containing the full pair.

Every package `README.md` documents: purpose, the configuration block as a table, the JSON
output schema with a field reference, the Intune setup steps (including run-context and
64-bit settings), and caveats.

---

## 7. Registry-specific rules

- **Always use `-LiteralPath`.** Registry key names legitimately contain `[`, `]`, and `*`,
  which `-Path` treats as wildcards.
- **Read values through the `RegistryKey` object**, not `Get-ItemProperty`. `Get-Item` on a
  registry path returns a `Microsoft.Win32.RegistryKey`, whose `GetValueNames()`,
  `GetValueKind()` and `GetValue()` distinguish "value is absent" from "value is `0`" —
  `Get-ItemProperty` cannot, and it also injects `PSPath`/`PSParentPath` noise.
- **Read `ExpandString` raw** with
  `[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames`, otherwise a
  comparison is made against the expanded value and never matches the configured one.
- **Compare by type**: byte arrays as hex, `MultiString` as `|`-joined, everything else as a
  case-insensitive string.
- **Set "Run script in 64-bit PowerShell" to Yes** in Intune. Otherwise `HKLM:\SOFTWARE`
  is silently redirected to `HKLM:\SOFTWARE\WOW6432Node`. Target the 32-bit hive by naming
  `WOW6432Node` in the path explicitly, never by relying on redirection.
- **`HKCU:` under SYSTEM context is the SYSTEM profile, not the user's.** Any `HKCU:` target
  requires the remediation to run with logged-on credentials.

---

## 8. Checklist before committing a script

- [ ] Exactly one `Write-Output` in the file, inside `Write-IntuneResult`.
- [ ] No `Write-Host`, `Write-Error`, or `throw`.
- [ ] `$ErrorActionPreference = 'Stop'` set, whole body in `try/catch`.
- [ ] **Every value in the JSON is a scalar** — no arrays, no nested records, no `null`.
- [ ] **Column set is identical on every run**, including the `catch` path: all per-item
      columns pre-created before `try`. Verify by running the error scenario and diffing
      the field names against a success run.
- [ ] Per-item labels come from configuration, are sanitised to `[A-Za-z0-9_]`, and are
      de-duplicated.
- [ ] Exit codes match the §2 tables (detection `Error` → `0`; remediation `Error` → `1`).
- [ ] Config block byte-identical between the detect and remediate scripts.
- [ ] Remediation verifies its own result before reporting `Success`.
- [ ] `JsonLength` emitted, and worst-case output checked against the 2048-character limit;
      free-form values capped. Truncation = the device's row is silently dropped.
- [ ] Comment-based help complete, including `Run Context` and the output shape.
- [ ] Package `README.md` created or updated.
