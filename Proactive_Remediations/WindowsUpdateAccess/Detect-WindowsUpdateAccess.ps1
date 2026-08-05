<#
.SYNOPSIS
    Windows Update Access - Intune Remediation DETECTION script.

.DESCRIPTION
    Detects whether Windows Update access has been turned off on the device by the
    DisableWindowsUpdateAccess policy value, and reports the live state of that value.

        HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
            DisableWindowsUpdateAccess  (REG_DWORD)

    This is the "Turn off access to all Windows Update features" policy (ICM.admx /
    RemoveWindowsUpdate_ICM), under Computer Configuration > System > Internet
    Communication Management > Internet Communication settings. A value of 1 removes all
    Windows Update features, blocks automatic updating, and stops Device Manager pulling
    driver updates. A value of 0 restores access.

    States reported per target:
      * Compliant    - present and already 0.
      * NonCompliant - present and set to 1. Remediation will set it to 0.
      * Unexpected   - present but neither 0 nor 1. Left alone by default.
      * TypeMismatch - present but not a DWord. Left alone by default.
      * NotPresent   - policy not configured, which already allows access. Compliant.
      * Unknown      - target not reached because detection errored.

    The device is reported NonCompliant (exit 1) when any target needs remediation. If the
    registry cannot be read at all, the device is reported with Status "Error" and exit 0 -
    compliance is unknown, and remediating a device we could not assess is worse than
    leaving it alone.

    OUTPUT SHAPE: a single flat JSON object with FIXED scalar columns, one set per
    configured target (<Label>_Path / _Name / _Type / _Data / _State). In Power BI or
    Excel: Transform > Parse > JSON, expand, tick every field - one row per device.

    Run Context: SYSTEM   (the policy lives in HKLM.)

.NOTES
    Author        : Madhu Perera
    Script Version: 1.0
    Requirements  : Windows 10/11, Windows PowerShell 5.1
    Output        : Single-line JSON object to STDOUT. See Proactive_Remediations/CLAUDE.md.
    Reference     : https://learn.microsoft.com/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-update-error-code-0x8024002e

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Detect-WindowsUpdateAccess.ps1
#>

#region ---------------------------- CONFIG ----------------------------------------

# This block MUST be identical to the one in Remediate-WindowsUpdateAccess.ps1. Intune
# uploads the two scripts independently, so they cannot share a config file - edit both
# together.

$S_SolutionName  = 'WindowsUpdateAccess'
$S_ScriptVersion = '1.0'

# Policy values to enforce. Each entry produces its own set of output columns.
#   Label            - column-name prefix. Optional; defaults to Name.
#   Path             - full provider path. Wildcards are NOT expanded.
#   Name             - value name.
#   Type             - expected RegistryValueKind. Also the kind written by remediation.
#   NonCompliantData - the data that means "this needs fixing".
#   DesiredData      - what remediation writes.
$S_TargetValues = @(
    @{
        Label            = 'DisableWindowsUpdateAccess'
        Path             = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        Name             = 'DisableWindowsUpdateAccess'
        Type             = 'DWord'
        NonCompliantData = 1
        DesiredData      = 0
    }
)

# $false (default) - only an exact NonCompliantData match is remediated. Anything else that
#                    is present but not DesiredData is reported as Unexpected / TypeMismatch
#                    and left untouched.
# $true            - any present value that is not DesiredData is rewritten to DesiredData.
$S_RemediateUnexpectedData = $false

# $false (default) - an absent value is COMPLIANT. Not configured already allows Windows
#                    Update access, so writing a value would create policy where the device
#                    had none.
# $true            - remediation creates the key and value set to DesiredData.
$S_CreateIfMissing = $false

# Character cap for a single <Label>_Data column.
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
        absent" is distinguishable from "value is 0" - which is the entire point here, since
        0 is the compliant state and absent is a different (also compliant) state.
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
    <# Classifies a target against what is actually on the device. #>
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

    $F_Current = ConvertTo-ComparableString -F_Data $F_Info.Data

    if ($F_Current -ieq (ConvertTo-ComparableString -F_Data $F_Target.DesiredData))      { return 'Compliant' }
    if ($F_Current -ieq (ConvertTo-ComparableString -F_Data $F_Target.NonCompliantData)) { return 'NonCompliant' }

    return 'Unexpected'
}

function Test-NeedsRemediation
{
    <#
        Single source of truth for "should this target be written", shared by the detection
        and remediation scripts so they can never disagree about what is in scope.
    #>
    param([string]$F_State)

    switch ($F_State)
    {
        'NonCompliant' { return $true }
        'NotPresent'   { return [bool]$S_CreateIfMissing }
        'Unexpected'   { return [bool]$S_RemediateUnexpectedData }
        'TypeMismatch' { return [bool]$S_RemediateUnexpectedData }
        default        { return $false }
    }
}

#endregion -------------------------------------------------------------------------


#region ---------------------------- MAIN ------------------------------------------

$ErrorActionPreference = 'Stop'

# Built before the try block, with every per-target column pre-created and defaulted, so
# the catch path emits exactly the same column set as a successful run. Power BI needs the
# columns to be identical across all devices, including the ones that errored.
$F_Data = [ordered]@{
    TargetCount         = @($S_TargetValues).Count
    NeedsRemediation    = 0
    CompliantCount      = 0
    NotPresentCount     = 0
    UnexpectedCount     = 0
}

$F_UsedLabels = New-Object System.Collections.Generic.HashSet[string]
$F_Labels     = @()

foreach ($F_Target in $S_TargetValues)
{
    $F_Label = Resolve-UniqueLabel -F_Label (Get-TargetLabel -F_Target $F_Target) -F_Used $F_UsedLabels
    $F_Labels += $F_Label

    $F_Data["${F_Label}_Path"]  = [string]$F_Target.Path
    $F_Data["${F_Label}_Name"]  = [string]$F_Target.Name
    $F_Data["${F_Label}_Type"]  = ''
    $F_Data["${F_Label}_Data"]  = ''
    $F_Data["${F_Label}_State"] = 'Unknown'
}

try
{
    for ($F_Index = 0; $F_Index -lt @($S_TargetValues).Count; $F_Index++)
    {
        $F_Target = $S_TargetValues[$F_Index]
        $F_Label  = $F_Labels[$F_Index]

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
            'Compliant'    { $F_Data.CompliantCount++ }
            'NotPresent'   { $F_Data.NotPresentCount++ }
            'NonCompliant' { }
            default        { $F_Data.UnexpectedCount++ }
        }

        if (Test-NeedsRemediation -F_State $F_State) { $F_Data.NeedsRemediation++ }
    }

    if ($F_Data.NeedsRemediation -gt 0)
    {
        $F_Summary = "Windows Update access is turned off: $($F_Data.NeedsRemediation) policy value(s) need remediation. " +
                     "$($F_Data.CompliantCount) already compliant; $($F_Data.NotPresentCount) not configured; $($F_Data.UnexpectedCount) unexpected."

        Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'NonCompliant' -F_Data $F_Data -F_Summary $F_Summary
        exit 1
    }

    $F_Summary = "Windows Update access is not restricted by policy. " +
                 "$($F_Data.CompliantCount) value(s) set as desired; $($F_Data.NotPresentCount) not configured; $($F_Data.UnexpectedCount) unexpected but out of scope."

    Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'Compliant' -F_Data $F_Data -F_Summary $F_Summary
    exit 0
}
catch
{
    # Compliance is UNKNOWN, not bad. Exit 0 so Intune does not remediate a device that
    # could not be assessed; Status = 'Error' is what surfaces the failure in reporting.
    # Any target not reached keeps its pre-initialised State of 'Unknown'.
    Write-IntuneResult -F_ScriptType 'Detection' -F_Status 'Error' -F_Data $F_Data `
                       -F_Summary 'Detection failed; Windows Update access policy state could not be determined.' `
                       -F_ErrorMessage $_.Exception.Message
    exit 0
}

#endregion -------------------------------------------------------------------------
