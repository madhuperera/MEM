# Personal Storage Reporting

A single PowerShell script, deployed via **Microsoft Intune Remediations** as a
**detection script only**, that measures the size of a defined list of subfolders
under a root folder and reports the results as JSON for **Power BI / Excel**.

> **Reporting only.** This solution takes **no remediation action** and never marks a
> device as non-compliant. It always exits `0`. It is purely a storage data collector.

---

## Overview

- Runs in **user context** so it can read the signed-in user's profile and OneDrive paths.
- You define a **root folder path** and an **explicit list of subfolder names** to check.
- For each subfolder it measures **size (MB and GB)** and **file count**.
- It calculates the **total size** across all listed subfolders.
- A configurable **capacity threshold** (default **1 GB**) drives a single device-level
  **`Over<N>GB`** (`Yes`/`No`) column (e.g. `Over1GB`), evaluated against the **combined
  total** of all in-scope subfolders (not any individual folder).
- Output is a compact, single-line **flat JSON object written to STDOUT** (one record per
  device) which Intune captures in the *Pre-remediation detection output* column. Parsing
  it as JSON in Power BI / Excel gives **one row per device** — each subfolder is its own
  set of columns, with no nested lists and no row-per-subfolder explosion.

---

## Script

### `Detect-PersonalStorageReport.ps1`

Used in the **Detection** slot of an Intune Remediation. There is intentionally **no
remediation script**.

#### Configuration block (top of the script)

| Variable | Default | Purpose |
|---|---|---|
| `$RootFolderPath` | `$env:USERPROFILE` | Root the subfolders live under. Supports environment variables. |
| `$SubFolders` | `Desktop, Documents, Downloads, Pictures, Videos, Music` | Explicit list of direct child subfolder names to measure. |
| `$CapacityThresholdGB` | `1` | Threshold (GB) that drives the `Over<N>GB` column (e.g. `Over1GB`), checked against the **combined total**. |

Edit these values before uploading to Intune. Each subfolder adds only ~60 characters of
output, so the JSON stays well under the Intune limit for typical lists (see below).

---

## JSON output schema

A **single flat JSON object per device**. Each subfolder contributes its own columns
(`<Subfolder>_SizeMB`, `<Subfolder>_SizeGB`, `<Subfolder>_ItemCount`). There are **no
arrays and no nested objects**, so parsing it yields exactly **one row per device**.

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
  "TotalSizeMB": 192.65,
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
| `ParentFolderPath` | The resolved root folder all subfolders live under. |
| `<Subfolder>_SizeMB` / `<Subfolder>_SizeGB` | That subfolder's size, rounded to 2 decimals. |
| `<Subfolder>_ItemCount` | Recursive **file** count in that subfolder. |
| `TotalSizeMB` / `TotalSizeGB` | Combined size of all listed subfolders. |
| `Over<N>GB` | `Yes` if the **combined total** ≥ the threshold, else `No`. The column name uses the configured threshold (e.g. `Over1GB`). |

> A subfolder that does not exist reports `0` for its size and item-count columns.

---

## Intune setup

1. Go to **Intune admin center → Devices → Scripts and remediations → Create**.
2. **Detection script file:** upload `Detect-PersonalStorageReport.ps1`.
3. **Remediation script file:** leave **empty** (reporting only).
4. Settings:
   - **Run this script using the logged-on credentials:** **Yes** (user context).
   - **Enforce script signature check:** No (unless you sign it).
   - **Run script in 64-bit PowerShell:** Yes.
5. **Assign** to the target device/user group and set a schedule (e.g. daily).

> **Output limit:** Intune stores up to **2048 characters** of the detection script's
> STDOUT in the *Pre-remediation detection output* column. Each subfolder adds only ~60
> characters (three columns), so a typical list fits comfortably. Confirm the output
> length if you configure a very large number of subfolders.

---

## Power BI / Excel import

The data source is the **Remediation results export** from Intune, which contains the
*Pre-remediation detection output* column (the JSON).

### Power BI

1. **Get Data** → load the exported remediation results (CSV).
2. Select the detection-output column → **Transform → Parse → JSON**. Each cell becomes
   a **Record** (one device).
3. Click the **expand** (⇄) icon on that column → tick the fields you want
   (`DeviceName`, the `<Subfolder>_Size*` columns, `TotalSizeGB`, `Over1GB`, …).
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
- **Missing folders:** reported with `Exists: false` and zero size/count, not skipped.
- **PowerShell version:** written for **Windows PowerShell 5.1** (the Intune Management
  Extension default).
