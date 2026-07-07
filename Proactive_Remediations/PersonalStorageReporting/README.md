# Personal Storage Reporting

A single PowerShell script, deployed via **Microsoft Intune Remediations** as a
**detection script only**, that measures the size of a defined list of subfolders
under a root folder and reports the results as JSON for **Power BI / Excel**.

> **Reporting only.** This solution takes **no remediation action** and never marks a
> device as non-compliant. It always exits `0`. It is purely a storage data collector.

### Versions

| Script | Status | Adds |
|---|---|---|
| `Detect-PersonalStorageReport.ps1` (v1) | **Frozen** — do not change | Exact-name subfolder sizing. |
| `Detect-PersonalStorageReport_v2.ps1` (v2) | Current | Everything v1 does **plus** wildcard **groups** (e.g. `OneDrive*`) whose matches are summed under one label, with an **exclude** list for OneDrive for Business. |
| `Detect-PersonalStorageReport_v3.ps1` (v3) | Current | **Discovery.** Sorts *every* non-hidden top-level profile folder into category **buckets** (Known / Supported / Legacy / UnmanagedOneDrive / **Other**). The **Other** bucket surfaces folders the user created that fall outside the known categories — the migration signal. See [v3 section](#v3--profile-folder-discovery). |

v2 is a **superset** of v1 — the exact-subfolder columns are identical. v3 is a **different
purpose** (discover unknown folders, not measure known ones), so it is its own script.
Deploy whichever fits the question you're answering; v1 stays untouched as the baseline.

---

## Overview

- Runs in **user context** so it can read the signed-in user's profile and OneDrive paths.
- You define a **root folder path** plus two kinds of targets:
  - **Exact subfolders** (`$SubFolders`) — measured by exact name; one column set each.
  - **Wildcard groups** (`$FolderGroups`, v2) — a **Label** you choose + a **Match**
    pattern (e.g. `OneDrive*`). **Every** folder matching the pattern (minus
    `$ExcludeFolders`) is **summed** into that one Label, and the discovered names are
    listed in a companion column. Columns stay identical across devices even when the
    actual folder names differ (`OneDrive`, `OneDrive - Personal`, …).
- For each target it measures **size (MB and GB)** and **file count**.
- A configurable **capacity threshold** (default **1 GB**) drives a single device-level
  **`Over<N>GB`** (`Yes`/`No`) column (e.g. `Over1GB`), evaluated against the **combined
  total** of all targets (exact subfolders + groups), not any individual folder.
- Output is a compact, single-line **flat JSON object written to STDOUT** (one record per
  device) which Intune captures in the *Pre-remediation detection output* column. Parsing
  it as JSON in Power BI / Excel gives **one row per device** — each target is its own set
  of columns, with no nested lists and no row-per-folder explosion.

---

## Script

Used in the **Detection** slot of an Intune Remediation. There is intentionally **no
remediation script**.

#### Configuration block (top of the script)

| Variable | Default | Purpose |
|---|---|---|
| `$RootFolderPath` | `$env:USERPROFILE` | Root the targets live under. Supports environment variables. |
| `$SubFolders` | `Desktop, Pictures, Documents` | Exact-name subfolders to measure. One column set each. |
| `$FolderGroups` *(v2)* | `@{ Label='UnmanagedOneDrive'; Match='OneDrive*' }` | Wildcard groups. Each is a `Label` (your stable column prefix) + a `Match` pattern. All matches are summed under the Label. |
| `$ExcludeFolders` *(v2)* | `OneDrive - Contoso` | Names / patterns (support `*` and `?`) excluded from wildcard-group matches — use for approved / OneDrive for Business folders. |
| `$CapacityThresholdGB` | `1` | Threshold (GB) driving the `Over<N>GB` column (e.g. `Over1GB`), checked against the **combined total**. |

Edit these values before uploading to Intune.

- **Set `$ExcludeFolders` to your tenant's business folder name(s).** Because the remediation
  is deployed per client, the tenant name is known — e.g. `'OneDrive - Contoso'`. This keeps
  OneDrive for Business out of the report so it does not generate noise.
- Each subfolder adds ~60 characters and each group ~110 characters of output, so the JSON
  stays well under the Intune limit for typical lists (see below).

---

## JSON output schema

A **single flat JSON object per device**. Each exact subfolder and each wildcard group
contributes its own columns. There are **no arrays and no nested objects**, so parsing it
yields exactly **one row per device**.

```json
{
  "DeviceName": "RF-1234",
  "UserName": "JohnDoe",
  "CollectionTimeUtc": "2026-06-26T11:23:59Z",
  "ParentFolderPath": "C:\\Users\\JohnDoe",
  "Desktop_SizeMB": 12.30,
  "Desktop_SizeGB": 0.01,
  "Desktop_ItemCount": 8,
  "Pictures_SizeMB": 0.00,
  "Pictures_SizeGB": 0.00,
  "Pictures_ItemCount": 0,
  "Documents_SizeMB": 180.35,
  "Documents_SizeGB": 0.18,
  "Documents_ItemCount": 47,
  "UnmanagedOneDrive_SizeMB": 3.50,
  "UnmanagedOneDrive_SizeGB": 0.00,
  "UnmanagedOneDrive_ItemCount": 3,
  "UnmanagedOneDrive_FoldersFound": "OneDrive; OneDrive - Personal",
  "UnmanagedOneDrive_FolderCount": 2,
  "TotalSizeMB": 196.15,
  "TotalSizeGB": 0.19,
  "Over1GB": "No"
}
```

### Field reference

| Field | Description |
|---|---|
| `DeviceName` | Computer name (`$env:COMPUTERNAME`). |
| `UserName` | Signed-in user the script ran as. |
| `CollectionTimeUtc` | Collection timestamp, UTC (ISO 8601). |
| `ParentFolderPath` | The resolved root folder all targets live under. |
| `<Subfolder>_SizeMB` / `<Subfolder>_SizeGB` | That exact subfolder's size, rounded to 2 decimals. |
| `<Subfolder>_ItemCount` | Recursive **file** count in that subfolder. |
| `<Label>_SizeMB` / `<Label>_SizeGB` | *(group)* Combined size of **all** matched folders, summed. |
| `<Label>_ItemCount` | *(group)* Combined recursive **file** count across matched folders. |
| `<Label>_FoldersFound` | *(group)* The actual folder names that matched, sorted alphabetically and `; `-separated into a **single string** (`""` if none). It is deliberately a string, **not** a JSON array, so the Power BI JSON transform stays flat with no nested list to expand. |
| `<Label>_FolderCount` | *(group)* How many folders matched (after exclusions). |
| `TotalSizeMB` / `TotalSizeGB` | Combined size of **all** targets (exact subfolders + groups). |
| `Over<N>GB` | `Yes` if the **combined total** ≥ the threshold, else `No`. The column name uses the configured threshold (e.g. `Over1GB`). |

> A subfolder or group that matches nothing reports `0` for its size and item-count columns
> (a group also reports `""` folders found and a count of `0`).

---

## v3 — Profile Folder Discovery

`Detect-PersonalStorageReport_v3.ps1` answers a different question: *which folders under the
profile does the user actually keep data in* — so you can plan a migration. Rather than
measuring a known list, it **discovers** every non-hidden top-level folder and sorts each
into exactly one **category bucket**, then aggregates size / file count / folder count per
bucket. Still a single flat JSON object — **one row per device**.

### Buckets

| Bucket | What lands here |
|---|---|
| `Known` | Managed standard folders — `Desktop`, `Documents`, `Pictures`. |
| `Supported` | Still-legitimate common folders — `Downloads`, `Music`, `Videos`. |
| `Legacy` | Deprecated / relic folders nobody should use on a work device — `Favorites`, `Contacts`, `Searches`, `Links`, `3D Objects`, `Saved Games`. |
| `UnmanagedOneDrive` | Any `OneDrive*` folder **not** in `$ExcludeFolders` (consumer OneDrive, not the company one). |
| `Other` | **Everything else = folders the user created.** The migration signal; names are listed in `Other_FoldersFound`. |

### How classification works

- **Hidden / system folders are skipped for free.** The top-level scan does *not* use
  `-Force`, so `AppData`, legacy junctions, etc. never appear. (Sizing *inside* a kept
  folder *does* use `-Force`, so hidden files within a real user folder still count.)
- **Reparse points / junctions are skipped** to avoid loops and double-counting.
- **The company OneDrive is excluded** via `$ExcludeFolders` (set it to your tenant's
  folder name, e.g. `OneDrive - Contoso`).
- **Standard known folders are matched by their real path, not a hard-coded name.** Their
  paths are resolved at runtime with `[Environment]::GetFolderPath` (which reads the
  logged-on user's shell-folder config), so a **localized display name is matched by its
  actual path** — e.g. a profile that shows *Favourites* in Explorer is still classified
  correctly because the on-disk known-folder path is what's compared. A *stray*
  second folder with a different spelling isn't the real known-folder path, so it correctly
  falls into `Other`.
- **Precedence:** excluded → `UnmanagedOneDrive` → path-resolved known folder → category
  name-list → `Other`.

### v3 configuration block

| Variable | Default | Purpose |
|---|---|---|
| `$KnownFolders` | `Desktop, Documents, Pictures` | Name-list for the Known bucket. |
| `$SupportedFolders` | `Downloads, Music, Videos` | Name-list for the Supported bucket. |
| `$LegacyFolders` | `Favorites, Contacts, Searches, Links, 3D Objects, Saved Games` | Name-list for the Legacy bucket. |
| `$OneDriveMatch` | `OneDrive*` | Pattern for the UnmanagedOneDrive bucket. |
| `$ExcludeFolders` | `OneDrive - Contoso` | Company OneDrive (and anything else) to exclude entirely. |
| `$CapacityThresholdGB` | `1` | Drives `Over<N>GB` against the combined total. |

### v3 output columns (one row per device)

Device: `DeviceName`, `UserName`, `CollectionTimeUtc`, `ParentFolderPath`.

For each bucket (`Known`, `Supported`, `Legacy`, `UnmanagedOneDrive`, `Other`):
`<Bucket>_SizeMB`, `<Bucket>_SizeGB`, `<Bucket>_ItemCount`, `<Bucket>_FolderCount`,
`<Bucket>_FoldersFound` (sorted, `; `-separated **string**).

Summary: `TotalSizeMB`, `TotalSizeGB`, `Over<N>GB`.

> **Migration workflow:** filter Power BI to rows where `Other_FolderCount > 0` (or
> `Other_SizeMB` is significant) to find users with data outside the standard folders, and
> read `Other_FoldersFound` to see exactly which folders need a plan.

---

## Intune setup

1. Go to **Intune admin center → Devices → Scripts and remediations → Create**.
2. **Detection script file:** upload the script for the question you're answering —
   `Detect-PersonalStorageReport_v2.ps1` (measure known folders + OneDrive groups),
   `Detect-PersonalStorageReport_v3.ps1` (discover *all* profile folders by category), or
   the frozen `Detect-PersonalStorageReport.ps1` (exact-subfolder sizing only).
3. **Remediation script file:** leave **empty** (reporting only).
4. Settings:
   - **Run this script using the logged-on credentials:** **Yes** (user context).
   - **Enforce script signature check:** No (unless you sign it).
   - **Run script in 64-bit PowerShell:** Yes.
5. **Assign** to the target device/user group and set a schedule (e.g. daily).

> **Output limit:** Intune stores up to **2048 characters** of the detection script's
> STDOUT in the *Pre-remediation detection output* column. Each exact subfolder adds ~60
> characters and each wildcard group ~110 characters, so a typical config fits comfortably.
> Confirm the output length if you configure a very large number of targets.

---

## Power BI / Excel import

The data source is the **Remediation results export** from Intune, which contains the
*Pre-remediation detection output* column (the JSON).

### Power BI

1. **Get Data** → load the exported remediation results (CSV).
2. Select the detection-output column → **Transform → Parse → JSON**. Each cell becomes
   a **Record** (one device).
3. Click the **expand** (⇄) icon on that column → tick the fields you want
   (`DeviceName`, the `<Subfolder>_Size*` columns, the `<Label>_*` group columns such as
   `UnmanagedOneDrive_SizeGB` / `UnmanagedOneDrive_FoldersFound`, `TotalSizeGB`, `Over1GB`, …).
4. Result: a flat table, **one row per device** — ready to slice, chart, and filter
   (e.g. `Over1GB = "Yes"`).

### Excel

Use **Data → Get Data → From JSON** (or Power Query as above): the object loads as a
record, then expand the columns — same single-row-per-device result as Power BI.

---

## Notes & caveats

- **OneDrive Files On-Demand:** reading `.Length` reports the *logical* size of
  online-only files **without hydrating (downloading)** them, so reporting is accurate
  and non-disruptive.
- **Access-denied / locked items:** sizing ignores items it cannot read
  (`-ErrorAction SilentlyContinue`) so a single bad path never blanks the report.
- **Missing folders:** reported as `0` size/count (and, for a group, `""` folders found),
  not skipped — every device still produces a full row.
- **OneDrive for Business exclusion:** business folders are matched by `$ExcludeFolders`
  (by name / pattern). Set it to your tenant's folder name (e.g. `OneDrive - Contoso`) so
  business OneDrive is never included. Consumer folders (`OneDrive`, `OneDrive - Personal`)
  are reported.
- **User context is required (v3):** known-folder resolution via
  `[Environment]::GetFolderPath` reads the *logged-on user's* shell-folder config, so the
  Intune remediation must run with **logged-on credentials**. Run as SYSTEM would resolve
  the wrong profile.
- **No disk writes:** all versions emit only to STDOUT (the Intune output column); nothing
  is written to the device.
- **PowerShell version:** written for **Windows PowerShell 5.1** (the Intune Management
  Extension default).
