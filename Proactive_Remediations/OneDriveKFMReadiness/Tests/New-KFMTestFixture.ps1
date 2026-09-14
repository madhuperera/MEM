<#
.SYNOPSIS
    Builds (or removes) a folder tree of files that violate OneDrive / Known Folder Move
    rules, for testing Detect-OneDriveKFMReadiness.ps1.

.DESCRIPTION
    TEST HELPER ONLY - never deploy through Intune. Creates a fixture folder containing:

      * Long paths     - a nest whose CURRENT path already exceeds 260 characters, and one
                         file that is under 260 today but crosses it once the OneDrive
                         folder name is added (the "projected" case).
      * Invalid names  - ~$ prefix, _vti_, .lock, CON / LPT1 (reserved device names),
                         leading and trailing spaces, a folder starting with U+309B, and
                         files placed under those bad folders.
      * Reparse points - a junction (no admin needed) and, if the account is allowed to,
                         a file symbolic link. Both point INSIDE the fixture so cleanup can
                         never follow a link into real data.
      * Controls       - clean files, and a name using # and % (only flagged when
                         $S_TreatHashPercentAsInvalid is set in the detection script).

    Reserved names, trailing spaces and over-length paths are blocked by Win32, not by
    NTFS, so they are created through the \\?\ prefix - the same prefix the detection
    script scans with. The characters " * : < > ? / \ | cannot exist on NTFS at all; the
    script tries one anyway and reports the expected failure so you can see that rule is
    untestable on a Windows disk.

    When finished it prints the counts the detection script should report for the
    fixture. Point the detection script at the fixture with an explicit path, e.g.
        @{ Label = 'Documents'; Path = 'C:\Users\JohnDoe\Documents\KFMTest' }

    -Cleanup removes the fixture. The junction and symlink are deleted as links first,
    then the tree is removed through the \\?\ prefix (Explorer cannot delete these names).

    Run Context: the signed-in user, Windows PowerShell 5.1 or PowerShell 7. Not elevated -
    a junction does not need it; the symlink step is skipped if the privilege is missing.

.PARAMETER Path
    Fixture root. Default: %USERPROFILE%\Documents\KFMTest. Choose a native NTFS path -
    a Parallels / network share will refuse several of these names.

.PARAMETER OneDriveFolderName
    Must match $S_OneDriveFolderName in the detection script. Used only to size the
    "projected" long-path case and to print the expected numbers.

.PARAMETER Cleanup
    Remove the fixture instead of creating it.

.EXAMPLE
    .\New-KFMTestFixture.ps1
    .\New-KFMTestFixture.ps1 -Path 'C:\Users\JohnDoe\Documents\KFMTest' -Cleanup

.NOTES
    Author        : Madhu Perera
    Script Version: 1.0
#>

[CmdletBinding()]
param
(
    [string]$Path = (Join-Path $env:USERPROFILE 'Documents\KFMTest'),

    [string]$OneDriveFolderName = 'OneDrive - Contoso',

    [switch]$Cleanup
)

#region ---------------------------- FUNCTIONS -------------------------------------

function ConvertTo-PrefixedPath
{
    <# Applies the \\?\ (or \\?\UNC\) prefix so Win32 name and length checks are bypassed. #>
    param([string]$F_Path)

    if ($F_Path.StartsWith('\\?\')) { return $F_Path }
    if ($F_Path.StartsWith('\\'))   { return '\\?\UNC\' + $F_Path.Substring(2) }
    return '\\?\' + $F_Path
}

function New-FixtureItem
{
    <#
        Creates one file or directory and records the outcome in $script:F_Log. Items
        that Win32 rejects are created through the \\?\ prefix; if New-Item still refuses,
        the .NET APIs are tried with the same prefix. Returns $true on success.
    #>
    param
    (
        [string]$F_Path,
        [ValidateSet('File', 'Directory')]
        [string]$F_Type,
        [string]$F_Expect,          # what the detection script should report it as
        [switch]$F_Prefix,
        [switch]$F_ExpectFailure    # NTFS is expected to refuse this one
    )

    $F_Target = $(if ($F_Prefix) { ConvertTo-PrefixedPath -F_Path $F_Path } else { $F_Path })
    $F_Ok     = $false
    $F_Error  = ''

    try
    {
        $null = New-Item -Path $F_Target -ItemType $F_Type -Force -ErrorAction Stop
        $F_Ok = $true
    }
    catch
    {
        $F_Error = $_.Exception.Message
        if ($F_Prefix)
        {
            try
            {
                if ($F_Type -eq 'Directory') { $null = [System.IO.Directory]::CreateDirectory($F_Target) }
                else                         { [System.IO.File]::WriteAllText($F_Target, 'x') }
                $F_Ok    = $true
                $F_Error = ''
            }
            catch
            {
                $F_Error = $_.Exception.Message
            }

            # Last resort: cmd.exe has always accepted \\?\ paths.
            if (-not $F_Ok -and $env:OS -eq 'Windows_NT')
            {
                if ($F_Type -eq 'Directory') { & cmd.exe /c mkdir "$F_Target" 2>&1 | Out-Null }
                else                         { & cmd.exe /c "echo x> `"$F_Target`"" 2>&1 | Out-Null }
                if (Test-Path -LiteralPath $F_Target) { $F_Ok = $true; $F_Error = '' }
            }
        }
    }

    $F_Result = $(if ($F_Ok) { 'Created' } elseif ($F_ExpectFailure) { 'NotCreatable (expected)' } else { 'FAILED' })

    $script:F_Log.Add([pscustomobject]@{
        Result = $F_Result
        Type   = $F_Type
        Expect = $F_Expect
        Item   = $F_Path.Substring($script:F_RootLength).TrimStart('\')
        Error  = $F_Error
    })

    return $F_Ok
}

function New-FixtureLink
{
    <# Creates a junction or symbolic link; a missing privilege is reported, not fatal. #>
    param
    (
        [string]$F_Path,
        [string]$F_Target,
        [ValidateSet('Junction', 'SymbolicLink')]
        [string]$F_Kind
    )

    $F_Ok    = $false
    $F_Error = ''

    try
    {
        $null = New-Item -Path $F_Path -ItemType $F_Kind -Value $F_Target -ErrorAction Stop
        $F_Ok = $true
    }
    catch
    {
        $F_Error = $_.Exception.Message
    }

    $script:F_Log.Add([pscustomobject]@{
        Result = $(if ($F_Ok) { 'Created' } elseif ($F_Kind -eq 'SymbolicLink') { 'Skipped (needs privilege)' } else { 'FAILED' })
        Type   = $F_Kind
        Expect = 'Link'
        Item   = $F_Path.Substring($script:F_RootLength).TrimStart('\')
        Error  = $F_Error
    })

    return $F_Ok
}

function Remove-Fixture
{
    <#
        Deletes links as links first (never through them), then the tree via \\?\ so
        reserved names, trailing spaces and long paths come off cleanly.
    #>
    param([string]$F_Root)

    if (-not (Test-Path -LiteralPath $F_Root))
    {
        Write-Output "Nothing to remove: $F_Root does not exist."
        return
    }

    foreach ($F_Link in @((Join-Path $F_Root 'LinkToClean'), (Join-Path $F_Root 'SymlinkToOk.txt')))
    {
        if (-not (Test-Path -LiteralPath $F_Link)) { continue }
        try
        {
            $F_Item = Get-Item -LiteralPath $F_Link -Force
            if ($F_Item.PSIsContainer) { [System.IO.Directory]::Delete($F_Link) }   # removes the junction only
            else                       { [System.IO.File]::Delete($F_Link) }
        }
        catch
        {
            Write-Output "WARNING: could not remove link $F_Link : $($_.Exception.Message)"
        }
    }

    # Prefixed first (handles reserved names, trailing spaces and long paths), then plain,
    # then cmd.exe - which has always coped with \\?\ paths.
    $F_Attempts = @((ConvertTo-PrefixedPath -F_Path $F_Root), $F_Root)
    foreach ($F_Attempt in $F_Attempts)
    {
        if (-not (Test-Path -LiteralPath $F_Root)) { break }
        try   { Remove-Item -LiteralPath $F_Attempt -Recurse -Force -ErrorAction Stop }
        catch { }
    }

    if ((Test-Path -LiteralPath $F_Root) -and $env:OS -eq 'Windows_NT')
    {
        & cmd.exe /c rmdir /s /q "$(ConvertTo-PrefixedPath -F_Path $F_Root)" 2>&1 | Out-Null
    }

    if (Test-Path -LiteralPath $F_Root) { Write-Output "FAILED to remove $F_Root - delete it manually with: cmd /c rmdir /s /q `"\\?\$F_Root`"" }
    else                                { Write-Output "Removed $F_Root" }
}

#endregion -------------------------------------------------------------------------


#region ---------------------------- MAIN ------------------------------------------

$ErrorActionPreference = 'Stop'

$F_Root = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($Path)).TrimEnd('\')
$script:F_RootLength = $F_Root.Length
$script:F_Log        = New-Object System.Collections.Generic.List[object]

if ($Cleanup)
{
    Remove-Fixture -F_Root $F_Root
    exit 0
}

if ($F_Root -like "*\$OneDriveFolderName\*" -or $F_Root -like "*\$OneDriveFolderName")
{
    Write-Output "Refusing to build the fixture inside the OneDrive folder ($F_Root) - the sync client would try to upload it."
    exit 1
}

if (Test-Path -LiteralPath $F_Root)
{
    Write-Output "$F_Root already exists. Run with -Cleanup first, or choose another -Path."
    exit 1
}

Write-Output "Building fixture under $F_Root"
Write-Output ''

$null = New-Item -Path $F_Root -ItemType Directory -Force

# ---- Controls (clean) -----------------------------------------------------------------
$null = New-FixtureItem -F_Path "$F_Root\Clean"                       -F_Type Directory -F_Expect 'Clean'
$null = New-FixtureItem -F_Path "$F_Root\Clean\ok.txt"                -F_Type File      -F_Expect 'Clean'
$null = New-FixtureItem -F_Path "$F_Root\Clean\Report 2026.docx"      -F_Type File      -F_Expect 'Clean (inner spaces are fine)'
$null = New-FixtureItem -F_Path "$F_Root\Clean\budget#2026%.xlsx"     -F_Type File      -F_Expect 'Clean unless TreatHashPercentAsInvalid'

# ---- Invalid names creatable without tricks ----------------------------------------------
$null = New-FixtureItem -F_Path "$F_Root\~`$Report.docx"              -F_Type File      -F_Expect 'Name:Tilde'
$null = New-FixtureItem -F_Path "$F_Root\notes_vti_bin.txt"           -F_Type File      -F_Expect 'Name:vti'
$null = New-FixtureItem -F_Path "$F_Root\.lock"                       -F_Type File      -F_Expect 'Name:Reserved'
$null = New-FixtureItem -F_Path "$F_Root\ LeadingSpace"               -F_Type Directory -F_Expect 'Name:Space (folder)'
$null = New-FixtureItem -F_Path "$F_Root\ LeadingSpace\inside.txt"    -F_Type File      -F_Expect 'BadName via parent folder'
$null = New-FixtureItem -F_Path "$F_Root\$([char]0x309B)Folder"       -F_Type Directory -F_Expect 'Name:FirstChar (folder)'
$null = New-FixtureItem -F_Path "$F_Root\$([char]0x309B)Folder\photo.jpg" -F_Type File  -F_Expect 'BadName via parent folder'

# ---- Invalid names that need the \\?\ prefix ---------------------------------------------
$null = New-FixtureItem -F_Path "$F_Root\CON.txt"                     -F_Type File      -F_Expect 'Name:Reserved' -F_Prefix
$null = New-FixtureItem -F_Path "$F_Root\LPT1"                        -F_Type File      -F_Expect 'Name:Reserved' -F_Prefix
$null = New-FixtureItem -F_Path "$F_Root\TrailingSpace.txt "          -F_Type File      -F_Expect 'Name:Space'    -F_Prefix
$null = New-FixtureItem -F_Path "$F_Root\TrailingSpaceFolder "        -F_Type Directory -F_Expect 'Name:Space (folder)' -F_Prefix
$null = New-FixtureItem -F_Path "$F_Root\TrailingSpaceFolder \inside.txt" -F_Type File  -F_Expect 'BadName via parent folder' -F_Prefix

# ---- Characters NTFS itself refuses (expected to fail) -----------------------------------
$null = New-FixtureItem -F_Path "$F_Root\star*name.txt"               -F_Type File      -F_Expect 'Name:Char' -F_Prefix -F_ExpectFailure

# ---- Long paths -----------------------------------------------------------------------
# Already over 260 today: two 100-character folders and an 80-character file name.
$F_Deep = "$F_Root\LongPath\" + ('a' * 100) + '\' + ('a' * 100)
$null = New-FixtureItem -F_Path $F_Deep -F_Type Directory -F_Expect 'Deep folder (current path > 260)' -F_Prefix
foreach ($F_N in 1..3)
{
    $null = New-FixtureItem -F_Path "$F_Deep\$(('b' * 76))_$F_N.txt" -F_Type File -F_Expect 'Len (current > 260)' -F_Prefix
}

# Under 260 today, over it once "<OneDriveFolderName>\" is inserted. The detection script
# projects <OneDriveRoot>\<fixture leaf>\..., so size the name so the projected length
# lands at exactly 260 + 5.
$F_ProjectedPrefixLength = $env:USERPROFILE.TrimEnd('\').Length + 1 + $OneDriveFolderName.Length + 1 + (Split-Path $F_Root -Leaf).Length + 1
$F_NameLength = 265 - $F_ProjectedPrefixLength - 'ProjectedOnly\'.Length - '.txt'.Length
if ($F_NameLength -ge 20 -and $F_NameLength -le 200)
{
    $null = New-FixtureItem -F_Path "$F_Root\ProjectedOnly" -F_Type Directory -F_Expect 'Clean'
    $null = New-FixtureItem -F_Path "$F_Root\ProjectedOnly\$(('p' * $F_NameLength)).txt" -F_Type File -F_Expect 'Len (only after OneDrive name added)' -F_Prefix
}
else
{
    Write-Output "Skipping the projected-only case: fixture path is too long or too short to construct it (needed name length $F_NameLength)."
}

# ---- Reparse points (targets are inside the fixture) -------------------------------------
$null = New-FixtureLink -F_Path "$F_Root\LinkToClean"     -F_Target "$F_Root\Clean"        -F_Kind Junction
$null = New-FixtureLink -F_Path "$F_Root\SymlinkToOk.txt" -F_Target "$F_Root\Clean\ok.txt" -F_Kind SymbolicLink

# ---- Report -------------------------------------------------------------------------------
$script:F_Log | Format-Table -Property Result, Type, Expect, Item -AutoSize | Out-String -Width 200 | Write-Output

$F_Failed = @($script:F_Log | Where-Object { $_.Result -eq 'FAILED' })
foreach ($F_Item in $F_Failed) { Write-Output "FAILED  $($F_Item.Item): $($F_Item.Error)" }

# Expected detection-script numbers, derived from what was actually created.
$F_Created     = @($script:F_Log | Where-Object { $_.Result -eq 'Created' })
$F_Files       = @($F_Created | Where-Object { $_.Type -eq 'File' })
$F_LongPaths   = @($F_Files | Where-Object { $_.Expect -like 'Len*' }).Count
$F_BadNames    = @($F_Files | Where-Object { $_.Expect -like 'Name:*' -or $_.Expect -like 'BadName via*' }).Count
$F_BadFolders  = @($F_Created | Where-Object { $_.Type -eq 'Directory' -and $_.Expect -like 'Name:*' }).Count
$F_Links       = @($F_Created | Where-Object { $_.Expect -eq 'Link' }).Count

Write-Output ''
Write-Output "Expected Detect-OneDriveKFMReadiness.ps1 output for a folder pointed at $F_Root"
Write-Output "(with `$S_OneDriveFolderName = '$OneDriveFolderName' and `$S_TreatHashPercentAsInvalid = `$false):"
Write-Output ''
Write-Output ("  {0,-12} {1}" -f '_State',      'NotReady')
Write-Output ("  {0,-12} {1}" -f '_Files',      $F_Files.Count)
Write-Output ("  {0,-12} {1}" -f '_LongPaths',  $F_LongPaths)
Write-Output ("  {0,-12} {1}" -f '_BadNames',   $F_BadNames)
Write-Output ("  {0,-12} {1}" -f '_BadFolders', $F_BadFolders)
Write-Output ("  {0,-12} {1}" -f '_Links',      $F_Links)
Write-Output ''
Write-Output "Point the detection script at it with:  @{ Label = 'Documents'; Path = '$F_Root' }"
Write-Output "Remove it with:                         .\New-KFMTestFixture.ps1 -Path '$F_Root' -Cleanup"

exit 0

#endregion -------------------------------------------------------------------------
