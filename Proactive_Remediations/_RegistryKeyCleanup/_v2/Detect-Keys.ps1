<#
.SYNOPSIS
    Registry Key Cleanup v2 - Intune Remediation DETECTION script.

.DESCRIPTION
    Reports the live state of every configured registry target on the device, and flags the
    device NonCompliant when any of them is in scope for removal.

    Each target value is evaluated against three things:
      * Path      - the key it lives under.
      * Name      - the value name.
      * Type      - the registry value kind (DWord, String, ...). Compared when supplied.
      * Data      - the value data. Compared only when MatchData is $true, which lets you
                    remove a value outright regardless of what it currently holds.

    Every target reports its own State:
      * InScope      - present and matching, so Remediate-Keys.ps1 will remove it.
      * DataMismatch - present but holding different data. Left alone.
      * TypeMismatch - present but the wrong value kind. Left alone.
      * NotPresent   - already clean.

    OUTPUT SHAPE: a single flat JSON object with FIXED columns - one set per configured
    target, named <Label>_Path / _Name / _Type / _Data / _State. Every value is a scalar;
    there are no arrays and no nested objects. In Power BI or Excel this means
    Transform > Parse > JSON, then expand and tick every field: one row per device, with
    the full path / name / type / current data of each targeted registry value as its own
    column. Because the column set comes from the configuration rather than from what
    happens to exist on the device, the columns are identical across every device.

    The device is reported NonCompliant (exit 1) when one or more targets are InScope. If
    the registry cannot be read at all, the device is reported with Status "Error" and
    exit 0 - compliance is unknown, and remediating a device we could not assess is worse
    than leaving it alone.

    Run Context: SYSTEM   (HKCU: targets require logged-on credentials instead - under
                           SYSTEM, HKCU: resolves to the SYSTEM profile, not the user's.)

.NOTES
    Author        : Madhu Perera
    Script Version: 2.0
    Requirements  : Windows 10/11, Windows PowerShell 5.1
    Output        : Single-line JSON object to STDOUT. See Proactive_Remediations/CLAUDE.md.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-Keys.ps1
#>

#region ---------------------------- CONFIG ----------------------------------------

# This block MUST be identical to the one in Remediate-Keys.ps1. Intune uploads the two
# scripts independently, so they cannot share a config file - edit both together.

$S_SolutionName  = 'RegistryKeyCleanup'
$S_ScriptVersion = '2.0'

# Registry VALUES to remove. Each entry produces its own set of output columns.
#   Label     - column-name prefix for this target. Optional; defaults to Name. Anything
#               other than a letter or digit becomes '_'. Must be unique across targets -
#               duplicates are suffixed _2, _3 automatically.
#   Path      - full provider path. Use HKLM: / HKCU: / HKU:. Wildcards are NOT expanded.
#   Name      - value name (the default value is not supported).
#   Type      - expected RegistryValueKind: DWord, QWord, String, ExpandString,
#               MultiString, Binary. Omit the key entirely to skip the type comparison.
#   Data      - expected data. Only used when MatchData is $true.
#   MatchData - $true  : remove ONLY when the current data equals Data (default).
#               $false : remove whenever the value exists, whatever it holds.
#
# SIZE LIMIT: Intune stores only the first 2048 characters of STDOUT, and a truncated line
# is invalid JSON that Power BI drops entirely. Each value target costs roughly 220
# characters, so keep to about 7 targets with long key paths (more with short ones). The
# script reports its own output length in JsonLength - check it after any config change.
$S_TargetValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; Name = 'bProtectedMode';                   Type = 'DWord'; Data = 1; MatchData = $true }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; Name = 'iProtectedView';                   Type = 'DWord'; Data = 2; MatchData = $true }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; Name = 'bEnableProtectedModeAppContainer'; Type = 'DWord'; Data = 1; MatchData = $true }
)

# Whole registry KEYS to remove, including every value and subkey beneath them. Each entry
# produces <Label>_Path and <Label>_State columns, where State is Present or NotPresent.
# Leave empty unless you really mean it - there is no data comparison guarding these.
#   @{ Label = 'RetiredProduct'; Path = 'HKLM:\SOFTWARE\Policies\Vendor\RetiredProduct' }
$S_TargetKeys = @()

# Character cap for a single <Label>_Data column. Registry strings and binary blobs can be
# arbitrarily long; anything over this is truncated with a trailing '...'.
$S_MaxDataLength = 100

#endregion -------------------------------------------------------------------------


#region ---------------------------- FUNCTIONS -------------------------------------

function Write-IntuneResult
{
    <#
        Emits the standard single-line JSON object to STDOUT. Called EXACTLY ONCE, as the
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

function ConvertTo-ComparableString
{
    <#
        Normalises registry data of any kind into a single string, both for comparing
        current against expected and for reporting the value in a <Label>_Data column.
        Byte arrays become hex, MultiString becomes '|'-joined, everything else is
        stringified.
    #>
    param($F_Data)

    if ($null -eq $F_Data) { return '' }

    if ($F_Data -is [byte[]])
    {
        return (($F_Data | ForEach-Object { $_.ToString('X2') }) -join '')
    }

    if ($F_Data -is [string[]])
    {
        return ($F_Data -join '|')
    }

    return [string]$F_Data
}

function Format-DataField
{
    <# Caps a <Label>_Data column so one huge registry value cannot blow the size limit. #>
    param
    (
        [string]$F_Text,
        [int]$F_MaxLength
    )

    if ([string]::IsNullOrEmpty($F_Text)) { return '' }
    if ($F_Text.Length -le $F_MaxLength)  { return $F_Text }

    return ($F_Text.Substring(0, $F_MaxLength) + '...')
}

function Get-TargetLabel
{
    <#
        Builds the column-name prefix for a target: the configured Label, or the value
        Name, reduced to letters, digits and underscores so it is safe as a column header.
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
    <#
        Guarantees label uniqueness. Two targets sharing a label would silently overwrite
        each other's columns in the ordered output dictionary, losing a whole target from
        the report.
    #>
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

function Get-RegistryValueInfo
{
    <#
        Returns the current data and kind of a registry value, or $null when the key or the
        value does not exist.

        Reads through the RegistryKey object rather than Get-ItemProperty so that "value is
        absent" is distinguishable from "value is 0", and reads ExpandString raw so an
        expected value like '%SystemRoot%\...' is compared as written, not as expanded.
    #>
    param
    (
        [string]$F_Path,
        [string]$F_Name
    )

    $F_Key = Get-Item -LiteralPath $F_Path -ErrorAction SilentlyContinue
    if ($null -eq $F_Key) { return $null }

    if ($F_Key.GetValueNames() -notcontains $F_Name) { return $null }

    return [pscustomobject]@{
        Data = $F_Key.GetValue($F_Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        Kind = $F_Key.GetValueKind($F_Name)
    }
}

function Get-TargetState
{
    <#
        Classifies a target against what is actually on the device. Only 'InScope' means
        the value will be removed; the mismatch states exist so a value that is present but
        unexpected is visible in the report rather than indistinguishable from a clean
        device.
    #>
    param
    (
        [hashtable]$F_Target,
        $F_Info
    )

    if ($null -eq $F_Info) { return 'NotPresent' }

    if ($F_Target.ContainsKey('Type') -and -not [string]::IsNullOrWhiteSpace([string]$F_Target.Type))
    {
        if ($F_Info.Kind.ToString() -ine [string]$F_Target.Type) { return 'TypeMismatch' }
    }

    $F_MatchData = $true
    if ($F_Target.ContainsKey('MatchData')) { $F_MatchData = [bool]$F_Target.MatchData }

    if ($F_MatchData)
    {
        $F_Current  = ConvertTo-ComparableString -F_Data $F_Info.Data
        $F_Expected = ConvertTo-ComparableString -F_Data $F_Target.Data
        if ($F_Current -ine $F_Expected) { return 'DataMismatch' }
    }

    return 'InScope'
}

#endregion -------------------------------------------------------------------------


#region ---------------------------- MAIN ------------------------------------------

$ErrorActionPreference = 'Stop'

# Built before the try block, with every per-target column pre-created and defaulted, so
# the catch path emits exactly the same column set as a successful run. Power BI needs the
# columns to be identical across all devices, including the ones that errored.
$F_Data = [ordered]@{
    TargetValueCount = @($S_TargetValues).Count
    TargetKeyCount   = @($S_TargetKeys).Count
    InScopeCount     = 0
    MismatchCount    = 0
    NotPresentCount  = 0
}

$F_UsedLabels   = New-Object System.Collections.Generic.HashSet[string]
$F_ValueLabels  = @()
$F_KeyLabels    = @()

foreach ($F_Target in $S_TargetValues)
{
    $F_Label = Resolve-UniqueLabel -F_Label (Get-TargetLabel -F_Target $F_Target) -F_Used $F_UsedLabels
    $F_ValueLabels += $F_Label

    $F_Data["${F_Label}_Path"]  = [string]$F_Target.Path
    $F_Data["${F_Label}_Name"]  = [string]$F_Target.Name
    $F_Data["${F_Label}_Type"]  = ''
    $F_Data["${F_Label}_Data"]  = ''
    $F_Data["${F_Label}_State"] = 'Unknown'
}

foreach ($F_KeyTarget in $S_TargetKeys)
{
    $F_Label = Resolve-UniqueLabel -F_Label (Get-TargetLabel -F_Target $F_KeyTarget) -F_Used $F_UsedLabels
    $F_KeyLabels += $F_Label

    $F_Data["${F_Label}_Path"]  = [string]$F_KeyTarget.Path
    $F_Data["${F_Label}_State"] = 'Unknown'
}

try
{
    # --- Registry values ----------------------------------------------------------
    for ($F_Index = 0; $F_Index -lt @($S_TargetValues).Count; $F_Index++)
    {
        $F_Target = $S_TargetValues[$F_Index]
        $F_Label  = $F_ValueLabels[$F_Index]

        $F_Info  = Get-RegistryValueInfo -F_Path $F_Target.Path -F_Name $F_Target.Name
        $F_State = Get-TargetState -F_Target $F_Target -F_Info $F_Info

        # Report the CURRENT type and data found on the device, not the configured
        # expectation - that is what makes the export worth reading.
        if ($null -ne $F_Info)
        {
            $F_Data["${F_Label}_Type"] = $F_Info.Kind.ToString()
            $F_Data["${F_Label}_Data"] = Format-DataField -F_Text (ConvertTo-ComparableString -F_Data $F_Info.Data) -F_MaxLength $S_MaxDataLength
        }

        $F_Data["${F_Label}_State"] = $F_State

        switch ($F_State)
        {
            'InScope'    { $F_Data.InScopeCount++ }
            'NotPresent' { $F_Data.NotPresentCount++ }
            default      { $F_Data.MismatchCount++ }
        }
    }

    # --- Whole registry keys ------------------------------------------------------
    for ($F_Index = 0; $F_Index -lt @($S_TargetKeys).Count; $F_Index++)
    {
        $F_KeyTarget = $S_TargetKeys[$F_Index]
        $F_Label     = $F_KeyLabels[$F_Index]

        if (Test-Path -LiteralPath $F_KeyTarget.Path)
        {
            $F_Data["${F_Label}_State"] = 'Present'
            $F_Data.InScopeCount++
        }
        else
        {
            $F_Data["${F_Label}_State"] = 'NotPresent'
            $F_Data.NotPresentCount++
        }
    }

    if ($F_Data.InScopeCount -gt 0)
    {
        $F_Summary = "$($F_Data.InScopeCount) registry target(s) in scope for removal; " +
                     "$($F_Data.MismatchCount) present but not matching; $($F_Data.NotPresentCount) already clean."

        Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'NonCompliant' -F_Data $F_Data -F_Summary $F_Summary
        exit 1
    }

    $F_Summary = "No registry targets are in scope for removal. " +
                 "$($F_Data.MismatchCount) present but not matching; $($F_Data.NotPresentCount) already clean."

    Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'Compliant' -F_Data $F_Data -F_Summary $F_Summary
    exit 0
}
catch
{
    # Compliance is UNKNOWN, not bad. Exit 0 so Intune does not remediate a device that
    # could not be assessed; Status = 'Error' is what surfaces the failure in reporting.
    # Any target not reached keeps its pre-initialised State of 'Unknown'.
    Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'Error' -F_Data $F_Data `
                       -F_Summary 'Detection failed; registry compliance could not be determined.' `
                       -F_ErrorMessage $_.Exception.Message
    exit 0
}

#endregion -------------------------------------------------------------------------
