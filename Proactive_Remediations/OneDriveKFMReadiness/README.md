# OneDrive Known Folder Move Readiness

A single PowerShell script, deployed via **Microsoft Intune Remediations** as a
**detection script only**, that checks whether the signed-in user's **Desktop**,
**Documents** and **Pictures** folders can be moved into OneDrive for Business (Known
Folder Move or a manual migration) without files being left behind, and reports the
result as one flat JSON object per device for **Power BI / Excel**.

> **Reporting only.** There is no remediation script and nothing on the device is
> changed. By default a device that is *not ready* exits `1` so the Intune console shows
> it under **With issues** — set `$S_ExitNonCompliantWhenNotReady = $false` to always
> exit `0`.

Built to the [script standard](../CLAUDE.md): fixed scalar columns, one set per known
folder, so the output imports with **Transform → Parse → JSON → expand → tick every
field**, one row per device.

### Versions

| Script | Status | Adds |
|---|---|---|
| `Detect-OneDriveKFMReadiness.ps1` (v1.0) | **Current** | Projected path length, invalid names, reparse points, nested known folders; budgeted sample of offending paths. |

Planned (not yet built): writing the **full** list of offending paths to a report file in
the user's Documents folder. The JSON output can only ever carry a sample — see
[Output limit](#output-limit).

---

## What it checks

For **every file and folder** under each known folder:

| Check | Rule | Source |
|---|---|---|
| **Projected path length** | The path the item *will* have once it lives at `<profile>\<OneDrive folder>\<KnownFolder>\…`. Anything whose projected length is **≥ 260** (configurable) is a `LongPath` issue. A known folder already inside OneDrive is measured at its current path. | KFM guidance: "entire file path, including the file name, contains fewer than 260 characters". |
| **Invalid names** | Characters `" * : < > ? / \ \|` (optionally `#` `%`); leading/trailing space; names starting `~$`; `_vti_` anywhere; reserved names `.lock` `CON` `PRN` `AUX` `NUL` `COM0–9` `LPT0–9` (any extension); folders starting with `゛` (U+309B) or `ဧ` (U+1027). A **file under an invalid folder counts too** — it cannot sync. | OneDrive restrictions and limitations. |
| **Reparse points** | Junctions and symbolic links. Files On-Demand placeholders are *also* reparse points and are **not** counted (cloud attributes excluded; known folders already inside OneDrive skip this check). | KFM: "Folder contains a reparse point (junction point or symlink)". |
| **Nested known folders** | One known folder inside another (e.g. Pictures under Documents). Device-level flag only. | KFM: "Important folders aren't in the default locations". |

`desktop.ini` is skipped entirely — OneDrive manages it and every known folder has one.

### How the projected path is built

```
Current:    C:\Users\JohnDoe\Documents\MyLongFolder\LongFileName.txt      (58)
Projected:  C:\Users\JohnDoe\OneDrive - Contoso\Documents\MyLongFolder\LongFileName.txt   (79)
```

The known folder is recreated **by its on-disk name** directly under the OneDrive root.
The OneDrive root is `%USERPROFILE%\<$S_OneDriveFolderName>` unless the user already has
a business account whose sync folder has that name, in which case its real location is
read from `HKCU:\Software\Microsoft\OneDrive\Accounts\Business*\UserFolder`
(`OneDriveRootSource = Registry`).

### Not checked

Files > 250 GB, open/locked files, blocked file types, PST behaviour, and the OneDrive
**400-character cloud path** (server-relative, includes `personal/user_contoso_com/`).
On Windows the 260 limit is always hit first.

---

## Configuration block (top of the script)

| Variable | Default | Purpose |
|---|---|---|
| `$S_OneDriveFolderName` | `OneDrive - Contoso` | **Set this per tenant.** The sync folder name added to every projected path. |
| `$S_KnownFolders` | Desktop, Documents, Pictures | Folders to assess. `Label` is the column prefix; `SpecialFolder` is resolved at runtime from the signed-in user's shell-folder config (redirected/localised folders are found by real path). Optional `Path` overrides resolution. |
| `$S_MaxPathLength` | `260` | Projected length **≥** this is a LongPath issue. |
| `$S_TreatHashPercentAsInvalid` | `$false` | Also flag `#` and `%` (tenants that never enabled them). |
| `$S_IgnoreFileNames` | `desktop.ini` | Files skipped entirely. |
| `$S_SampleMaxItems` | `20` | Cap on paths listed in `IssueSample`. Also capped by the character budget. |
| `$S_SampleEntryMaxLength` | `90` | Longer sample entries are middle-elided with `...`. |
| `$S_MaxJsonLength` | `2000` | Target ceiling for the whole line (Intune stores 2048). |
| `$S_MaxScanDepth` | `64` | Nesting guard against junction loops. |
| `$S_ExitNonCompliantWhenNotReady` | `$true` | Exit `1` when any folder is NotReady (shows as *With issues* in Intune). |

---

## Status and exit codes

| `Status` | Meaning | Exit |
|---|---|---|
| `Compliant` | Every known folder found is ready (or none exist). | `0` |
| `NonCompliant` | At least one known folder is not ready. | `1` (or `0` if `$S_ExitNonCompliantWhenNotReady = $false`) |
| `Error` | Readiness could not be determined — including when run as SYSTEM. | `0` |

---

## JSON output schema

One flat object per device, no arrays, no nested records. Example (not ready):

```json
{"ScriptType":"Detection","Solution":"OneDriveKFMReadiness","ScriptVersion":"1.0","DeviceName":"RF-1234","UserName":"JohnDoe","RunContext":"User","CollectionTimeUtc":"2026-09-14T04:39:17Z","Status":"NonCompliant","OneDriveRootPath":"C:\\Users\\JohnDoe\\OneDrive - Contoso","OneDriveRootSource":"Registry","OneDriveSignedIn":"Yes","PathLengthLimit":260,"LongPathMode":"Prefixed","MigrationReady":"No","FoldersReady":1,"FoldersNotReady":2,"FoldersNotFound":0,"LongPathIssue":"Yes","InvalidNameIssue":"Yes","ReparsePointIssue":"Yes","NestedKnownFolders":"No","TotalFiles":11,"TotalLongPaths":3,"TotalBadNames":4,"TotalBadFolders":1,"TotalLinks":1,"ScanErrors":0,"Desktop_Path":"C:\\Users\\JohnDoe\\Desktop","Desktop_State":"NotReady","Desktop_InOneDrive":"No","Desktop_Files":1,"Desktop_LongPaths":0,"Desktop_BadNames":0,"Desktop_BadFolders":0,"Desktop_Links":1,"Desktop_MaxLen":52,"Documents_Path":"C:\\Users\\JohnDoe\\Documents","Documents_State":"NotReady","Documents_InOneDrive":"No","Documents_Files":9,"Documents_LongPaths":3,"Documents_BadNames":4,"Documents_BadFolders":1,"Documents_Links":0,"Documents_MaxLen":380,"Pictures_Path":"C:\\Users\\JohnDoe\\Pictures","Pictures_State":"Ready","Pictures_InOneDrive":"No","Pictures_Files":1,"Pictures_LongPaths":0,"Pictures_BadNames":0,"Pictures_BadFolders":0,"Pictures_Links":0,"Pictures_MaxLen":51,"IssueCount":8,"IssueSampleCount":6,"IssueSample":"[Name:Space] Documents\\ leadingspace\\; [Name:Tilde] Documents\\~$lock.docx; [Name:Reserved] Documents\\CON.txt; [Name:vti] Documents\\notes_vti_x.txt; [Link] Desktop\\link; [Len:380] Documents\\Folder_With_A_Rather_Lon...Name_9\\Quarterly_Report_Final_Version_1.docx; +2 more","Summary":"Not ready: Desktop, Documents. 3 long path(s), 5 invalid name(s), 1 link(s) across 11 file(s).","ErrorMessage":"","JsonLength":1810}
```

### Field reference

Envelope fields (`ScriptType` … `Status`, `Summary`, `ErrorMessage`, `JsonLength`) are as
defined in the [standard](../CLAUDE.md#envelope--always-present-always-these-names).

**Device-level**

| Field | Description |
|---|---|
| `OneDriveRootPath` | The OneDrive root used for projected paths. |
| `OneDriveRootSource` | `Registry` (real sync folder found for this user) or `Configured` (`%USERPROFILE%\<name>`). |
| `OneDriveSignedIn` | `Yes` if any OneDrive for Business account is configured for the user. |
| `PathLengthLimit` | The configured limit (260). |
| `LongPathMode` | `Prefixed` — scan used `\\?\` so files already over 260 characters were found. `Legacy` — they could not be enumerated and appear as `ScanErrors`. |
| `MigrationReady` | `Yes` when no folder is `NotReady` and no known folders are nested. **The headline column.** |
| `FoldersReady` / `FoldersNotReady` / `FoldersNotFound` | Per-state counts across the configured folders. |
| `LongPathIssue` / `InvalidNameIssue` / `ReparsePointIssue` / `NestedKnownFolders` | `Yes`/`No` — **what the device fails on**. |
| `TotalFiles` | Files scanned across all folders. |
| `TotalLongPaths` | Files whose projected path is ≥ the limit. |
| `TotalBadNames` | Files with an invalid name **or under an invalid folder**. |
| `TotalBadFolders` | Folders with an invalid name. |
| `TotalLinks` | Junctions / symlinks found. |
| `ScanErrors` | Directories that could not be read (access denied, or too long in `Legacy` mode). Non-zero means the numbers are a lower bound. |

**Per known folder** (`Desktop_*`, `Documents_*`, `Pictures_*`)

| Field | Description |
|---|---|
| `<Label>_Path` | Resolved on-disk path. Shows redirection to a file server, another drive, or OneDrive. `""` if unresolved. |
| `<Label>_State` | `Ready` / `NotReady` / `NotFound` / `Unknown` (errored before reaching it). |
| `<Label>_InOneDrive` | `Yes` if the folder already lives under the OneDrive root (KFM already applied). |
| `<Label>_Files` | Files scanned. |
| `<Label>_LongPaths` | Files over the projected-length limit. |
| `<Label>_BadNames` | Files with an invalid name or under an invalid folder. |
| `<Label>_BadFolders` | Folders with an invalid name. |
| `<Label>_Links` | Junctions / symlinks. |
| `<Label>_MaxLen` | Longest projected path found — how far over the limit the worst file is. |

**Sample** (last, free text)

| Field | Description |
|---|---|
| `IssueCount` | Total offending items (files with their own bad name, bad folders, links, long files). |
| `IssueSampleCount` | How many of them are listed in `IssueSample`. |
| `IssueSample` | `; `-separated string, up to 20 entries, **invalid names first, then links, then long paths** (shortest fix first). Each entry is `[Tag] <Label>\<relative path>`; folders end with `\`. Tags: `Name:Char` `Name:Space` `Name:Tilde` `Name:vti` `Name:Reserved` `Name:FirstChar` `Link` `Len:<projected length>`. Long entries are middle-elided. Ends with `+N more` when cut. |

---

## Intune setup

1. **Devices → Scripts and remediations → Create**.
2. **Detection script file:** `Detect-OneDriveKFMReadiness.ps1` (after setting
   `$S_OneDriveFolderName`).
3. **Remediation script file:** leave **empty**.
4. Settings:
   - **Run this script using the logged-on credentials:** **Yes** — mandatory. Under
     SYSTEM the script reports `Status = Error` and does nothing.
   - **Enforce script signature check:** No (unless you sign it).
   - **Run script in 64-bit PowerShell:** Yes.
5. Assign to the user/device group targeted for Known Folder Move; a daily or weekly
   schedule is plenty.

Scan time is proportional to the number of folders under Documents/Desktop/Pictures —
typically seconds, a few minutes for very large profiles.

---

## Power BI / Excel import

1. Load the Intune **Remediation results** export.
2. Select the *Pre-remediation detection output* column → **Transform → Parse → JSON**.
3. Click **expand** (⇄) → tick every field → OK. One row per device.
4. Useful views:
   - `MigrationReady = "No"` — devices needing attention before KFM.
   - `LongPathIssue`, `InvalidNameIssue`, `ReparsePointIssue`, `NestedKnownFolders` —
     slice by failure reason.
   - `Status = "Error"` — devices that could not be assessed (check `ErrorMessage`,
     and `RunContext = "System"` for a mis-configured assignment).
   - `ScanErrors > 0` — partial scans.
   - `Documents_InOneDrive = "Yes"` — already migrated.

---

## Testing

`Tests/New-KFMTestFixture.ps1` builds a folder of deliberately bad content so the
detection script can be exercised end to end. Explorer refuses most of these names, so the
helper creates them through the `\\?\` prefix — the same prefix the detection script
scans with.

```powershell
# Build (default: %USERPROFILE%\Documents\KFMTest) - not elevated
.\Tests\New-KFMTestFixture.ps1 -OneDriveFolderName 'OneDrive - Contoso'

# Point the detection script at it, then run it
#   @{ Label = 'Documents'; Path = 'C:\Users\JohnDoe\Documents\KFMTest' }

# Remove it (Explorer cannot delete these names)
.\Tests\New-KFMTestFixture.ps1 -Cleanup
```

It creates: a nest already over 260 characters, a file that only crosses 260 once the
OneDrive folder name is added, `~$`/`_vti_`/`.lock`/`CON`/`LPT1` names, leading- and
trailing-space names, a folder starting with `゛`, files under those bad folders, a
junction and (if permitted) a symlink — both pointing inside the fixture — plus clean
controls. It prints the `_Files` / `_LongPaths` / `_BadNames` / `_BadFolders` / `_Links`
values the detection script should report. The characters `" * : < > ? / \ |` cannot exist
on NTFS, so that rule is not testable on a Windows disk; the helper attempts one and shows
the expected failure.

> Use a native NTFS path. On a Parallels VM, `C:\Mac\Home\Documents` is a share and the
> known folders resolve there — use an explicit `Path` under `C:\Users\...` instead.

---

## Output limit

Intune keeps the first **2048 characters** of detection output; a truncated line is
invalid JSON and that device's row is lost. With the default three folders and typical
`C:\Users\<name>` paths the structured fields use roughly **1,450 characters**, leaving
~550 for `IssueSample` — enough for 5–10 short entries or 2–3 long-path entries. The
script measures the record first and fills the sample only with what fits, so the
structured columns are never at risk. `JsonLength` shows the real cost per device.

---

## Notes & caveats

- **Long paths.** Windows PowerShell 5.1 cannot normally open a path over 260
  characters. The scan enumerates through the `\\?\` prefix so files that are *already*
  too long are still found and measured (`LongPathMode = Prefixed`). If a host rejects
  the prefix, the script falls back (`Legacy`) and such folders show up in `ScanErrors`.
- **Files On-Demand.** Placeholders are reparse points with cloud attributes; they are
  never counted as links, and a known folder already inside OneDrive skips the link
  check entirely. No file is hydrated — only names and attributes are read.
- **Nested folders are double-scanned.** If Pictures sits inside Documents, its files
  are counted in both; `NestedKnownFolders = Yes` tells you why.
- **Localised folder names.** Known folders are resolved by path via
  `[Environment]::GetFolderPath`, so a localised display name does not matter. The
  projected path uses the folder's real on-disk name.
- **`~$` files** are Office lock files. They are transient but do get left behind, and
  Microsoft lists them as not allowed, so they are reported.
- **`#` and `%`** are allowed in current tenants. Flip `$S_TreatHashPercentAsInvalid`
  only if yours never enabled them.
- **No disk writes.** Output is STDOUT only. The on-disk full report is a planned v2.
- **PowerShell version:** Windows PowerShell 5.1 (Intune Management Extension default).

## References

- [Restrictions and limitations in OneDrive and SharePoint](https://support.microsoft.com/office/restrictions-and-limitations-in-onedrive-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa)
- [Back up your folders with OneDrive — Fix problems with folder backup](https://support.microsoft.com/office/back-up-your-folders-with-onedrive-d61a7930-a6fb-4b95-b28a-6552e77c3057)
- [Redirect and move Windows known folders to OneDrive](https://learn.microsoft.com/sharepoint/redirect-known-folders)
- [SharePoint limits — file path length](https://learn.microsoft.com/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-limits)
