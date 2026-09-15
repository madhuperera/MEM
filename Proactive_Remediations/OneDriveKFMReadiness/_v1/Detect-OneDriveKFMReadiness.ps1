<#
.SYNOPSIS
    OneDrive Known Folder Move Readiness - Intune Remediation DETECTION script (reporting only).

.DESCRIPTION
    Assesses whether the signed-in user's Desktop, Documents and Pictures folders can be
    moved into OneDrive for Business (Known Folder Move / manual migration) without files
    being left behind, and reports the result as ONE flat JSON object per device.

    For every file and folder under each known folder it checks:

      * Projected path length - the path the item WILL have once it lives under
        "<profile>\<OneDrive folder name>\<KnownFolder>\...". Microsoft's Known Folder
        Move guidance requires the entire file path, including the file name, to be
        fewer than 260 characters, so anything whose projected length is >= the
        configured limit is a LongPath issue. A known folder that is already inside the
        OneDrive root is measured at its current path.
      * Invalid names - the OneDrive for work or school restrictions: the characters
        " * : < > ? / \ | (optionally # and %), leading or trailing spaces, names starting
        with ~$, "_vti_" anywhere in a name, the reserved names .lock CON PRN AUX NUL
        COM0-COM9 LPT0-LPT9, and folders whose first character is U+309B or U+1027.
        A file under a folder with an invalid name is counted too - it cannot sync.
      * Reparse points - junctions and symbolic links, which Known Folder Move refuses to
        move. OneDrive Files On-Demand placeholders are also reparse points and are NOT
        counted: cloud attributes are excluded, and reparse points inside a known folder
        that already lives in OneDrive are ignored entirely.
      * Nested known folders - one known folder living inside another (e.g. Pictures
        under Documents), which Known Folder Move also refuses.

    desktop.ini is skipped entirely: OneDrive handles it itself and every known folder
    contains one.

    Per known folder the report gives the resolved on-disk path, a Ready / NotReady /
    NotFound state, whether it is already inside OneDrive, the counts for each issue type,
    the longest projected path found and the number of files scanned. Device-level
    columns roll those up and give a single MigrationReady Yes/No. A short, character-
    budgeted sample of offending paths (invalid names first, then reparse points, then
    long paths) closes the record. The full list does not fit Intune's 2048-character
    output limit by design; a future version will write it to the user's Documents folder.

    Status / exit code:
      * Compliant    (exit 0) - every known folder found is ready, or none exist.
      * NonCompliant (exit 1) - at least one known folder is not ready. No remediation
                               script is attached, so exit 1 only lights up "With issues"
                               in the Intune console. Set $S_ExitNonCompliantWhenNotReady
                               to $false to always exit 0.
      * Error        (exit 0) - readiness could not be determined, including when the
                               script was run as SYSTEM instead of the signed-in user.

    Long paths: on Windows the scan enumerates through the \\?\ prefix so files whose
    CURRENT path already exceeds 260 characters are still found and measured. If that
    prefix is rejected the scan falls back to normal enumeration and reports
    LongPathMode = Legacy, in which case such files surface as ScanErrors instead.

    OUTPUT SHAPE: a single flat JSON object with FIXED scalar columns, one set per
    configured known folder (<Label>_Path / _State / _InOneDrive / _Files / _LongPaths /
    _BadNames / _BadFolders / _Links / _MaxLen). In Power BI or Excel: Transform > Parse >
    JSON, expand, tick every field - one row per device.

    Run Context: USER - required because the known-folder locations, the OneDrive account
    and the profile path all belong to the signed-in user. Under SYSTEM the script reports
    Status = Error and does nothing else.

.NOTES
    Author        : Madhu Perera
    Script Version: 1.0
    Requirements  : Windows 10/11, Windows PowerShell 5.1
    Output        : Single-line JSON object to STDOUT. See Proactive_Remediations/CLAUDE.md.
    Reference     : https://support.microsoft.com/office/restrictions-and-limitations-in-onedrive-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa
                    https://support.microsoft.com/office/back-up-your-folders-with-onedrive-d61a7930-a6fb-4b95-b28a-6552e77c3057
                    https://learn.microsoft.com/sharepoint/redirect-known-folders

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-OneDriveKFMReadiness.ps1
#>

#region ---------------------------- CONFIG ----------------------------------------

# There is no matching Remediate- script for this solution: it is a reporting collector.

$S_SolutionName  = 'OneDriveKFMReadiness'
$S_ScriptVersion = '1.0'

# Name of the OneDrive for Business sync folder as it appears under the user profile.
# Known Folder Move puts the known folders directly under it, so this is what is added to
# every path: C:\Users\JohnDoe\Documents\x.docx -> C:\Users\JohnDoe\OneDrive - Contoso\Documents\x.docx
# If the signed-in user already has a business account whose sync folder has this name,
# its real location is read from the registry and used instead of <profile>\<name>.
$S_OneDriveFolderName = 'OneDrive - Contoso'

# Known folders to assess. Each entry produces its own fixed set of output columns.
#   Label         - column-name prefix. Keep it short; it is repeated across nine columns.
#   SpecialFolder - [System.Environment+SpecialFolder] member, resolved at runtime from the
#                   signed-in user's shell-folder configuration so a redirected or
#                   localised folder is found by its real path.
#   Path          - optional. Explicit path that bypasses SpecialFolder resolution.
$S_KnownFolders = @(
    @{ Label = 'Desktop';   SpecialFolder = 'Desktop'     }
    @{ Label = 'Documents'; SpecialFolder = 'MyDocuments' }
    @{ Label = 'Pictures';  SpecialFolder = 'MyPictures'  }
)

# A projected path whose length is >= this value is a LongPath issue. 260 is Windows
# MAX_PATH (259 usable characters plus the terminator) and matches Microsoft's Known
# Folder Move guidance of "fewer than 260 characters".
$S_MaxPathLength = 260

# $false (default) - # and % are allowed, which is the current OneDrive behaviour.
# $true            - also treat # and % as invalid, for tenants that never enabled them.
$S_TreatHashPercentAsInvalid = $false

# File names skipped entirely (not counted, not checked). desktop.ini is managed by
# OneDrive itself and exists in every known folder.
$S_IgnoreFileNames = @('desktop.ini')

# Maximum number of offending paths listed in IssueSample. The list is ALSO capped by the
# remaining character budget, so fewer may appear; "+N more" reports what was cut.
$S_SampleMaxItems = 20

# A single sample entry longer than this has its middle replaced with "..." so one long
# path cannot consume the whole sample budget.
$S_SampleEntryMaxLength = 90

# Target ceiling for the whole JSON line. Intune stores 2048 characters; the margin
# covers the JsonLength field and rounding.
$S_MaxJsonLength = 2000

# Directory nesting guard so a junction loop can never hang the scan.
$S_MaxScanDepth = 64

# $true  (default) - exit 1 when any known folder is NotReady, so the Intune console
#                    shows the device under "With issues". Nothing is remediated.
# $false           - always exit 0 (pure reporting, like PersonalStorageReporting).
$S_ExitNonCompliantWhenNotReady = $true

#endregion -------------------------------------------------------------------------


#region ---------------------------- FUNCTIONS -------------------------------------

function Write-IntuneResult
{
    <#
        Emits the standard single-line JSON object to STDOUT. Call EXACTLY ONCE, as the
        last action before exit. $F_Data is an [ordered] dictionary of solution fields,
        inserted between Status and Summary.

        -F_MeasureOnly returns the length the line WOULD have instead of writing it, so
        the caller can size the free-text sample to the remaining budget.
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

        [string]$F_ErrorMessage = '',

        [switch]$F_MeasureOnly
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

    if ($F_MeasureOnly) { return ($F_Json.Length + 20) }

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
    elseif ($F_Target.ContainsKey('SpecialFolder'))
    {
        $F_Label = [string]$F_Target.SpecialFolder
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

function Get-RunSid
{
    <# SID of the current token, or '' when it cannot be read. #>
    try   { return ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value }
    catch { return '' }
}

function Resolve-KnownFolderPath
{
    <#
        Real on-disk path of a configured known folder: the explicit Path if given,
        otherwise the SpecialFolder resolved from the signed-in user's shell-folder
        configuration. Returns '' when the folder cannot be resolved.
    #>
    param([hashtable]$F_Target)

    $F_Path = ''

    if ($F_Target.ContainsKey('Path') -and -not [string]::IsNullOrWhiteSpace([string]$F_Target.Path))
    {
        $F_Path = [System.Environment]::ExpandEnvironmentVariables([string]$F_Target.Path)
    }
    elseif ($F_Target.ContainsKey('SpecialFolder'))
    {
        try
        {
            $F_Member = [System.Enum]::Parse([System.Environment+SpecialFolder], [string]$F_Target.SpecialFolder)
            $F_Path   = [System.Environment]::GetFolderPath($F_Member)
        }
        catch
        {
            $F_Path = ''
        }
    }

    if ([string]::IsNullOrWhiteSpace($F_Path)) { return '' }

    return $F_Path.TrimEnd('\', '/')
}

function Get-OneDriveBusinessAccount
{
    <#
        Reads HKCU:\Software\Microsoft\OneDrive\Accounts\Business* for the signed-in user.
        AnyAccount   - a business account with a sync folder is configured.
        MatchedRoot  - the sync folder whose leaf name equals $S_OneDriveFolderName, or ''.
        A missing key simply means OneDrive is not set up; it is not an error.
    #>
    $F_Out = [pscustomobject]@{ AnyAccount = $false; MatchedRoot = '' }

    try
    {
        $F_Key = Get-Item -LiteralPath 'HKCU:\Software\Microsoft\OneDrive\Accounts' -ErrorAction Stop

        foreach ($F_SubName in $F_Key.GetSubKeyNames())
        {
            if ($F_SubName -notlike 'Business*') { continue }

            $F_Sub = $F_Key.OpenSubKey($F_SubName)
            if ($null -eq $F_Sub) { continue }

            $F_Folder = [string]$F_Sub.GetValue('UserFolder')
            $F_Sub.Close()

            if ([string]::IsNullOrWhiteSpace($F_Folder)) { continue }

            $F_Folder = $F_Folder.TrimEnd('\')
            $F_Out.AnyAccount = $true

            if ([System.IO.Path]::GetFileName($F_Folder) -ieq $S_OneDriveFolderName)
            {
                $F_Out.MatchedRoot = $F_Folder
            }
        }
    }
    catch
    {
        # No OneDrive account state for this user - fall back to the configured name.
    }

    return $F_Out
}

function Test-LongPathPrefix
{
    <#
        True when this host accepts \\?\-prefixed literal paths, which lets the scan see
        files whose current path already exceeds MAX_PATH. Always false off Windows.
    #>
    if ($env:OS -ne 'Windows_NT') { return $false }

    try
    {
        $null = Get-Item -LiteralPath ('\\?\' + $env:USERPROFILE) -Force -ErrorAction Stop
        return $true
    }
    catch
    {
        return $false
    }
}

function ConvertTo-EnumerationPath
{
    <# Applies the \\?\ (or \\?\UNC\) prefix to a path when long-path mode is on. #>
    param([string]$F_Path, [bool]$F_UsePrefix)

    if (-not $F_UsePrefix) { return $F_Path }
    if ($F_Path.StartsWith('\\?\')) { return $F_Path }
    if ($F_Path.StartsWith('\\')) { return '\\?\UNC\' + $F_Path.Substring(2) }

    return '\\?\' + $F_Path
}

function Test-InvalidName
{
    <#
        Applies the OneDrive for work or school name restrictions to ONE path segment.
        Returns a short reason code, or '' when the name is fine:
          Char      - contains " * : < > ? / \ | (or # % when configured)
          Space     - leading or trailing space
          Tilde     - starts with ~$ (Office lock file)
          vti       - contains _vti_
          Reserved  - .lock, CON, PRN, AUX, NUL, COM0-9, LPT0-9 (any extension), desktop.ini
          FirstChar - folder starting with U+309B or U+1027
    #>
    param([string]$F_Name, [bool]$F_IsFolder)

    if ($F_Name -match $script:F_InvalidCharPattern) { return 'Char' }
    if ($F_Name.StartsWith(' ') -or $F_Name.EndsWith(' ')) { return 'Space' }
    if ($F_Name.StartsWith('~$')) { return 'Tilde' }
    if ($F_Name.IndexOf('_vti_', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return 'vti' }

    $F_Lower = $F_Name.ToLowerInvariant()
    if ($F_Lower -eq '.lock' -or $F_Lower -eq 'desktop.ini') { return 'Reserved' }

    # Windows reserves these device names whatever the extension (CON.txt is still CON).
    $F_Base = $F_Lower.Split('.')[0]
    if ($F_Base -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])$') { return 'Reserved' }

    if ($F_IsFolder -and $F_Name.Length -gt 0)
    {
        $F_First = [int][char]$F_Name[0]
        if ($F_First -eq 0x309B -or $F_First -eq 0x1027) { return 'FirstChar' }
    }

    return ''
}

function Add-IssueEntry
{
    <#
        Records one offending path for the sample. Each kind keeps at most
        $S_SampleMaxItems entries; everything is still counted so "+N more" is accurate.
        Entries longer than $S_SampleEntryMaxLength are middle-elided.
    #>
    param
    (
        [hashtable]$F_Lists,
        [string]$F_Kind,
        [string]$F_Tag,
        [string]$F_Text
    )

    $F_Lists['Total'] = [int]$F_Lists['Total'] + 1

    $F_List = $F_Lists[$F_Kind]
    if ($F_List.Count -ge $S_SampleMaxItems) { return }

    $F_Entry = "[$F_Tag] $F_Text"
    if ($F_Entry.Length -gt $S_SampleEntryMaxLength)
    {
        $F_Keep  = [int](($S_SampleEntryMaxLength - 3) / 2)
        $F_Entry = $F_Entry.Substring(0, $F_Keep) + '...' + $F_Entry.Substring($F_Entry.Length - $F_Keep)
    }

    $F_List.Add($F_Entry)
}

function Invoke-KnownFolderScan
{
    <#
        Walks one known folder without following junctions or symbolic links, checking
        every file and folder for projected path length, invalid names and reparse points.
        Per-directory errors (access denied, path too long in Legacy mode) are counted in
        ScanErrors and the walk continues, so one bad folder never blanks the report.
    #>
    param
    (
        [string]$F_RootPath,        # real on-disk path, no prefix
        [string]$F_ProjectedRoot,   # where this folder will live after Known Folder Move
        [string]$F_Label,
        [bool]$F_UsePrefix,
        [bool]$F_InOneDrive,
        [hashtable]$F_IssueLists
    )

    $F_Result = [pscustomobject]@{
        Files      = 0
        LongPaths  = 0
        BadNames   = 0
        BadFolders = 0
        Links      = 0
        MaxLen     = 0
        ScanErrors = 0
    }

    $F_Stack = New-Object System.Collections.Generic.Stack[object]
    $F_Stack.Push([pscustomobject]@{
        Path            = (ConvertTo-EnumerationPath -F_Path $F_RootPath -F_UsePrefix $F_UsePrefix)
        Rel             = ''
        Depth           = 0
        AncestorInvalid = $false
    })

    while ($F_Stack.Count -gt 0)
    {
        $F_Dir = $F_Stack.Pop()

        $F_Children = @()
        try
        {
            $F_Children = @(Get-ChildItem -LiteralPath $F_Dir.Path -Force -ErrorAction Stop)
        }
        catch
        {
            $F_Result.ScanErrors++
            continue
        }

        foreach ($F_Child in $F_Children)
        {
            $F_Name  = [string]$F_Child.Name
            $F_IsDir = [bool]$F_Child.PSIsContainer

            if (-not $F_IsDir -and ($S_IgnoreFileNames -contains $F_Name)) { continue }

            $F_Rel = $(if ($F_Dir.Rel) { "$($F_Dir.Rel)\$F_Name" } else { $F_Name })

            # 0x400 ReparsePoint; 0x40000 RecallOnOpen and 0x400000 RecallOnDataAccess mark
            # Files On-Demand placeholders, which are reparse points OneDrive itself owns.
            $F_Attr    = [int]$F_Child.Attributes
            $F_IsLink  = (($F_Attr -band 0x400) -ne 0) -and (($F_Attr -band 0x440000) -eq 0) -and (-not $F_InOneDrive)

            if ($F_IsLink)
            {
                $F_Result.Links++
                Add-IssueEntry -F_Lists $F_IssueLists -F_Kind 'Link' -F_Tag 'Link' -F_Text "$F_Label\$F_Rel"
                continue   # never descend into a junction / symlink
            }

            $F_Reason  = Test-InvalidName -F_Name $F_Name -F_IsFolder $F_IsDir
            $F_NameBad = ($F_Reason -ne '') -or $F_Dir.AncestorInvalid

            if ($F_IsDir)
            {
                if ($F_Reason -ne '')
                {
                    $F_Result.BadFolders++
                    Add-IssueEntry -F_Lists $F_IssueLists -F_Kind 'Name' -F_Tag "Name:$F_Reason" -F_Text "$F_Label\$F_Rel\"
                }

                if ($F_Dir.Depth -lt $S_MaxScanDepth)
                {
                    $F_Stack.Push([pscustomobject]@{
                        Path            = [string]$F_Child.FullName
                        Rel             = $F_Rel
                        Depth           = $F_Dir.Depth + 1
                        AncestorInvalid = $F_NameBad
                    })
                }
                else
                {
                    $F_Result.ScanErrors++
                }

                continue
            }

            $F_Result.Files++

            $F_Length = ($F_ProjectedRoot + '\' + $F_Rel).Length
            if ($F_Length -gt $F_Result.MaxLen) { $F_Result.MaxLen = $F_Length }

            if ($F_Length -ge $S_MaxPathLength)
            {
                $F_Result.LongPaths++
                Add-IssueEntry -F_Lists $F_IssueLists -F_Kind 'Len' -F_Tag "Len:$F_Length" -F_Text "$F_Label\$F_Rel"
            }

            if ($F_NameBad)
            {
                $F_Result.BadNames++
                # A file under an invalid folder is covered by that folder's entry.
                if ($F_Reason -ne '')
                {
                    Add-IssueEntry -F_Lists $F_IssueLists -F_Kind 'Name' -F_Tag "Name:$F_Reason" -F_Text "$F_Label\$F_Rel"
                }
            }
        }
    }

    return $F_Result
}

function Build-IssueSample
{
    <#
        Joins sample entries - invalid names first, then reparse points, then long paths -
        into one '; '-separated string that fits the remaining JSON budget and the item
        cap. Returns the string and how many entries it holds; "+N more" covers the rest.
    #>
    param
    (
        [hashtable]$F_IssueLists,
        [int]$F_Budget
    )

    $F_Ordered = @()
    foreach ($F_Kind in @('Name', 'Link', 'Len')) { $F_Ordered += @($F_IssueLists[$F_Kind]) }

    $F_Total = [int]$F_IssueLists['Total']
    $F_Kept  = New-Object System.Collections.Generic.List[string]
    $F_Used  = 0

    foreach ($F_Entry in $F_Ordered)
    {
        if ($F_Kept.Count -ge $S_SampleMaxItems) { break }

        # JSON escaping doubles every backslash, so measure the escaped form.
        $F_Cost = ($F_Entry | ConvertTo-Json -Compress).Length - 2
        if ($F_Kept.Count -gt 0) { $F_Cost += 2 }

        # Leave room for a "; +N more" suffix.
        if (($F_Used + $F_Cost) -gt ($F_Budget - 16)) { break }

        $F_Kept.Add($F_Entry)
        $F_Used += $F_Cost
    }

    $F_Text = ($F_Kept -join '; ')
    if ($F_Total -gt $F_Kept.Count)
    {
        $F_More = $F_Total - $F_Kept.Count
        $F_Text = $(if ($F_Kept.Count -gt 0) { "$F_Text; +$F_More more" } else { "+$F_More more" })
    }

    return [pscustomobject]@{ Text = $F_Text; Count = $F_Kept.Count }
}

#endregion -------------------------------------------------------------------------


#region ---------------------------- MAIN ------------------------------------------

$ErrorActionPreference = 'Stop'

$script:F_InvalidCharPattern = $(if ($S_TreatHashPercentAsInvalid) { '["*:<>?/\\|#%]' } else { '["*:<>?/\\|]' })

# Built before the try block, with every per-folder column pre-created and defaulted, so
# the catch path emits exactly the same column set as a successful run. Power BI needs the
# columns to be identical across all devices, including the ones that errored.
$F_Data = [ordered]@{
    OneDriveRootPath    = ''
    OneDriveRootSource  = 'Unknown'
    OneDriveSignedIn    = 'Unknown'
    PathLengthLimit     = $S_MaxPathLength
    LongPathMode        = 'Unknown'
    MigrationReady      = 'Unknown'
    FoldersReady        = 0
    FoldersNotReady     = 0
    FoldersNotFound     = 0
    LongPathIssue       = 'Unknown'
    InvalidNameIssue    = 'Unknown'
    ReparsePointIssue   = 'Unknown'
    NestedKnownFolders  = 'Unknown'
    TotalFiles          = 0
    TotalLongPaths      = 0
    TotalBadNames       = 0
    TotalBadFolders     = 0
    TotalLinks          = 0
    ScanErrors          = 0
}

$F_UsedLabels = New-Object System.Collections.Generic.HashSet[string]
$F_Labels     = @()

foreach ($F_Target in $S_KnownFolders)
{
    $F_Label = Resolve-UniqueLabel -F_Label (Get-TargetLabel -F_Target $F_Target) -F_Used $F_UsedLabels
    $F_Labels += $F_Label

    $F_Data["${F_Label}_Path"]       = ''
    $F_Data["${F_Label}_State"]      = 'Unknown'
    $F_Data["${F_Label}_InOneDrive"] = 'Unknown'
    $F_Data["${F_Label}_Files"]      = 0
    $F_Data["${F_Label}_LongPaths"]  = 0
    $F_Data["${F_Label}_BadNames"]   = 0
    $F_Data["${F_Label}_BadFolders"] = 0
    $F_Data["${F_Label}_Links"]      = 0
    $F_Data["${F_Label}_MaxLen"]     = 0
}

# Free text goes last so a truncated line loses prose, not structured fields.
$F_Data['IssueCount']       = 0
$F_Data['IssueSampleCount'] = 0
$F_Data['IssueSample']      = ''

try
{
    # Everything this script measures belongs to the signed-in user. Under SYSTEM the
    # known folders and OneDrive account resolve to the wrong profile, so refuse to
    # report numbers that would look valid but describe nobody.
    if ((Get-RunSid) -eq 'S-1-5-18')
    {
        Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'Error' -F_Data $F_Data `
                           -F_Summary 'Script ran as SYSTEM; it must run with the logged-on user credentials.' `
                           -F_ErrorMessage 'Wrong run context: SYSTEM.'
        exit 0
    }

    # ---- OneDrive root -------------------------------------------------------------
    $F_ProfilePath = [string]$env:USERPROFILE
    $F_ProfilePath = $F_ProfilePath.TrimEnd('\', '/')

    $F_Account = Get-OneDriveBusinessAccount
    $F_Data.OneDriveSignedIn = $(if ($F_Account.AnyAccount) { 'Yes' } else { 'No' })

    if ($F_Account.MatchedRoot -ne '')
    {
        $F_OneDriveRoot = $F_Account.MatchedRoot
        $F_Data.OneDriveRootSource = 'Registry'
    }
    else
    {
        $F_OneDriveRoot = $F_ProfilePath + '\' + $S_OneDriveFolderName
        $F_Data.OneDriveRootSource = 'Configured'
    }
    $F_Data.OneDriveRootPath = $F_OneDriveRoot

    $F_UsePrefix = Test-LongPathPrefix
    $F_Data.LongPathMode = $(if ($F_UsePrefix) { 'Prefixed' } else { 'Legacy' })

    # ---- Resolve every known folder first (needed for the nesting check) ------------
    $F_Paths = @()
    foreach ($F_Target in $S_KnownFolders) { $F_Paths += (Resolve-KnownFolderPath -F_Target $F_Target) }

    $F_IssueLists = @{
        Total = 0
        Name  = (New-Object System.Collections.Generic.List[string])
        Link  = (New-Object System.Collections.Generic.List[string])
        Len   = (New-Object System.Collections.Generic.List[string])
    }

    $F_Nested   = $false
    $F_NotReady = @()

    for ($F_Index = 0; $F_Index -lt @($S_KnownFolders).Count; $F_Index++)
    {
        $F_Label = $F_Labels[$F_Index]
        $F_Path  = $F_Paths[$F_Index]

        $F_Data["${F_Label}_Path"] = $F_Path

        if ($F_Path -eq '' -or -not (Test-Path -LiteralPath $F_Path -PathType Container))
        {
            $F_Data["${F_Label}_State"]      = 'NotFound'
            $F_Data["${F_Label}_InOneDrive"] = 'No'
            $F_Data.FoldersNotFound++
            continue
        }

        # One known folder inside another blocks Known Folder Move outright.
        for ($F_Other = 0; $F_Other -lt $F_Paths.Count; $F_Other++)
        {
            if ($F_Other -eq $F_Index -or $F_Paths[$F_Other] -eq '') { continue }
            if ($F_Path.StartsWith($F_Paths[$F_Other] + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { $F_Nested = $true }
        }

        $F_InOneDrive = $F_Path.StartsWith($F_OneDriveRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)
        $F_Data["${F_Label}_InOneDrive"] = $(if ($F_InOneDrive) { 'Yes' } else { 'No' })

        # Already under OneDrive: the path will not change. Otherwise Known Folder Move
        # recreates the folder, by its on-disk name, directly under the OneDrive root.
        $F_ProjectedRoot = $(if ($F_InOneDrive) { $F_Path } else { $F_OneDriveRoot + '\' + [System.IO.Path]::GetFileName($F_Path) })

        $F_Scan = Invoke-KnownFolderScan -F_RootPath $F_Path -F_ProjectedRoot $F_ProjectedRoot -F_Label $F_Label `
                                         -F_UsePrefix $F_UsePrefix -F_InOneDrive $F_InOneDrive -F_IssueLists $F_IssueLists

        $F_Data["${F_Label}_Files"]      = $F_Scan.Files
        $F_Data["${F_Label}_LongPaths"]  = $F_Scan.LongPaths
        $F_Data["${F_Label}_BadNames"]   = $F_Scan.BadNames
        $F_Data["${F_Label}_BadFolders"] = $F_Scan.BadFolders
        $F_Data["${F_Label}_Links"]      = $F_Scan.Links
        $F_Data["${F_Label}_MaxLen"]     = $F_Scan.MaxLen

        $F_Data.TotalFiles      += $F_Scan.Files
        $F_Data.TotalLongPaths  += $F_Scan.LongPaths
        $F_Data.TotalBadNames   += $F_Scan.BadNames
        $F_Data.TotalBadFolders += $F_Scan.BadFolders
        $F_Data.TotalLinks      += $F_Scan.Links
        $F_Data.ScanErrors      += $F_Scan.ScanErrors

        if (($F_Scan.LongPaths + $F_Scan.BadNames + $F_Scan.BadFolders + $F_Scan.Links) -gt 0)
        {
            $F_Data["${F_Label}_State"] = 'NotReady'
            $F_Data.FoldersNotReady++
            $F_NotReady += $F_Label
        }
        else
        {
            $F_Data["${F_Label}_State"] = 'Ready'
            $F_Data.FoldersReady++
        }
    }

    # ---- Device-level roll-up ------------------------------------------------------
    $F_Data.LongPathIssue      = $(if ($F_Data.TotalLongPaths -gt 0) { 'Yes' } else { 'No' })
    $F_Data.InvalidNameIssue   = $(if (($F_Data.TotalBadNames + $F_Data.TotalBadFolders) -gt 0) { 'Yes' } else { 'No' })
    $F_Data.ReparsePointIssue  = $(if ($F_Data.TotalLinks -gt 0) { 'Yes' } else { 'No' })
    $F_Data.NestedKnownFolders = $(if ($F_Nested) { 'Yes' } else { 'No' })

    $F_Ready = ($F_Data.FoldersNotReady -eq 0) -and (-not $F_Nested)
    $F_Data.MigrationReady = $(if ($F_Ready) { 'Yes' } else { 'No' })
    $F_Data.IssueCount     = [int]$F_IssueLists['Total']

    if ($F_Ready)
    {
        $F_Summary = "Ready for Known Folder Move: $($F_Data.FoldersReady) folder(s) clean, $($F_Data.FoldersNotFound) not found, $($F_Data.TotalFiles) file(s) checked."
        $F_Status  = 'Compliant'
    }
    else
    {
        $F_Summary = "Not ready: $($F_NotReady -join ', '). $($F_Data.TotalLongPaths) long path(s), " +
                     "$($F_Data.TotalBadNames + $F_Data.TotalBadFolders) invalid name(s), $($F_Data.TotalLinks) link(s)"
        if ($F_Nested) { $F_Summary += ', nested known folders' }
        $F_Summary += " across $($F_Data.TotalFiles) file(s)."
        $F_Status   = $(if ($S_ExitNonCompliantWhenNotReady) { 'NonCompliant' } else { 'Compliant' })
    }
    if ($F_Data.ScanErrors -gt 0) { $F_Summary += " $($F_Data.ScanErrors) folder(s) could not be read." }

    # Size the sample to whatever the rest of the record leaves under the limit.
    $F_Baseline = Write-IntuneResult -F_ScriptType 'Detection' -F_Status $F_Status -F_Data $F_Data -F_Summary $F_Summary -F_MeasureOnly
    $F_Sample   = Build-IssueSample -F_IssueLists $F_IssueLists -F_Budget ($S_MaxJsonLength - $F_Baseline)

    $F_Data.IssueSampleCount = $F_Sample.Count
    $F_Data.IssueSample      = $F_Sample.Text

    Write-IntuneResult -F_ScriptType 'Detection' -F_Status $F_Status -F_Data $F_Data -F_Summary $F_Summary
    exit $(if ($F_Status -eq 'NonCompliant') { 1 } else { 0 })
}
catch
{
    # Readiness is UNKNOWN, not bad. Exit 0; Status = 'Error' surfaces it in reporting.
    # Any folder not reached keeps its pre-initialised State of 'Unknown'.
    Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'Error' -F_Data $F_Data `
                       -F_Summary 'Detection failed; Known Folder Move readiness could not be determined.' `
                       -F_ErrorMessage $_.Exception.Message
    exit 0
}

#endregion -------------------------------------------------------------------------
