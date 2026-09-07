<#
.SYNOPSIS
    Windows Update Policy Restrictions - Intune Remediation REMEDIATION script.

.DESCRIPTION
    Restores Windows Update by setting each of three restriction policy values back to 0
    where it has been set to 1.

        HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
            DisableWindowsUpdateAccess                    (REG_DWORD)  1 -> 0
            DoNotConnectToWindowsUpdateInternetLocations  (REG_DWORD)  1 -> 0
        HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
            NoAutoUpdate                                  (REG_DWORD)  1 -> 0

    These are the three values Microsoft names as "conflicting configurations" for Windows
    Autopatch and Windows Update for Business. Uses exactly the same scoping rules as
    Detect-WindowsUpdateAccess.ps1, sharing the Get-TargetState / Test-NeedsRemediation
    logic so the two can never disagree about what is in scope.

    Each target is handled independently: a failure on one does not stop the others, and
    every outcome is reported per target.

    By default it only rewrites a value that is exactly 1. A value that is absent is left
    alone (not configured already allows updates - writing one would create policy where
    the device had none, which matters most for the AU subkey, absent on a healthy device),
    and a value holding something unexpected is reported but not touched. Both behaviours
    are configurable below.

    Every write is verified by re-reading the registry: the value must come back as the
    desired data AND the desired kind, or it is reported as a failure.

    IMPORTANT: if these values are being set by an actual Group Policy or an Intune ADMX /
    settings-catalog policy, the next policy refresh will set them back to 1 and the device
    will oscillate between compliant and non-compliant forever. See the README - the fix in
    that case is to remove the policy at source, not to run this remediation.

    Run Context: SYSTEM   (all three values live in HKLM.)

.NOTES
    Author        : Madhu Perera
    Script Version: 1.1
    Requirements  : Windows 10/11, Windows PowerShell 5.1
    Output        : Single-line JSON object to STDOUT. See Proactive_Remediations/CLAUDE.md.
    Reference     : https://learn.microsoft.com/windows/deployment/windows-autopatch/references/windows-autopatch-conflicting-configurations
                    https://learn.microsoft.com/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-update-error-code-0x8024002e

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Remediate-WindowsUpdateAccess.ps1
#>

#region ---------------------------- CONFIG ----------------------------------------

# This block MUST be identical to the one in Detect-WindowsUpdateAccess.ps1. Intune
# uploads the two scripts independently, so they cannot share a config file - edit both
# together.

$S_SolutionName  = 'WindowsUpdateAccess'
$S_ScriptVersion = '1.1'

# Policy values to enforce. Each entry produces its own set of output columns.
#   Label            - column-name prefix. Optional; defaults to Name. Keep it short - it
#                      is repeated across five output columns, and the whole JSON record
#                      must stay under Intune's 2048-character STDOUT limit.
#   Path             - full provider path. Wildcards are NOT expanded.
#   Name             - value name.
#   Type             - expected RegistryValueKind. Also the kind written by remediation.
#   NonCompliantData - the data that means "this needs fixing".
#   DesiredData      - what remediation writes.
#
# These three values are the trio Microsoft names as "conflicting configurations" for
# Windows Autopatch / Windows Update for Business. Each one independently suppresses part
# of Windows Update, so all three are checked and reported separately - a device can be
# non-compliant on any one of them.
$S_TargetValues = @(
    # "Turn off access to all Windows Update features" (ICM.admx / RemoveWindowsUpdate_ICM).
    # 1 removes all Windows Update features and disables automatic updating.
    @{
        Label            = 'WUAccess'
        Path             = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        Name             = 'DisableWindowsUpdateAccess'
        Type             = 'DWord'
        NonCompliantData = 1
        DesiredData      = 0
    }

    # "Do not connect to any Windows Update Internet locations".
    # 1 stops the device reaching the public Windows Update service even for the metadata
    # it needs, which can also break Microsoft Store and Delivery Optimization.
    @{
        Label            = 'WUInternet'
        Path             = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        Name             = 'DoNotConnectToWindowsUpdateInternetLocations'
        Type             = 'DWord'
        NonCompliantData = 1
        DesiredData      = 0
    }

    # "Configure Automatic Updates" set to Disabled (WindowsUpdate.admx / AutoUpdateCfg).
    # 1 disables Automatic Updates; 0 is the documented default. Note this value lives in
    # the AU SUBKEY, which frequently does not exist at all on a healthy device.
    @{
        Label            = 'NoAutoUpdate'
        Path             = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        Name             = 'NoAutoUpdate'
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
#                    had none. This matters most for the AU subkey, which is absent on a
#                    healthy device and should stay that way.
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
# the catch path emits exactly the same column set as a successful run.
$F_Data = [ordered]@{
    TargetCount      = @($S_TargetValues).Count
    InScopeCount     = 0
    SetCount         = 0
    FailedCount      = 0
    AlreadyOkCount   = 0
}

$F_UsedLabels = New-Object System.Collections.Generic.HashSet[string]
$F_Labels     = @()

foreach ($F_Target in $S_TargetValues)
{
    $F_Label = Resolve-UniqueLabel -F_Label (Get-TargetLabel -F_Target $F_Target) -F_Used $F_UsedLabels
    $F_Labels += $F_Label

    $F_Data["${F_Label}_Path"]     = [string]$F_Target.Path
    $F_Data["${F_Label}_Name"]     = [string]$F_Target.Name
    $F_Data["${F_Label}_Action"]   = 'NotAttempted'
    $F_Data["${F_Label}_DataWas"]  = ''
    $F_Data["${F_Label}_DataNow"]  = ''
    $F_Data["${F_Label}_Error"]    = ''
}

try
{
    for ($F_Index = 0; $F_Index -lt @($S_TargetValues).Count; $F_Index++)
    {
        $F_Target = $S_TargetValues[$F_Index]
        $F_Label  = $F_Labels[$F_Index]

        $F_Info  = Get-RegistryValueInfo -F_Path $F_Target.Path -F_Name $F_Target.Name
        $F_State = Get-TargetState -F_Target $F_Target -F_Info $F_Info

        if ($null -ne $F_Info)
        {
            $F_Data["${F_Label}_DataWas"] = Format-DataField -F_Text (ConvertTo-ComparableString -F_Data $F_Info.Data) -F_MaxLength $S_MaxDataLength
            $F_Data["${F_Label}_DataNow"] = $F_Data["${F_Label}_DataWas"]
        }

        if (-not (Test-NeedsRemediation -F_State $F_State))
        {
            # Left deliberately: already correct, not configured, or holding data this
            # remediation is not scoped to touch.
            switch ($F_State)
            {
                'Compliant'  { $F_Data["${F_Label}_Action"] = 'AlreadyCompliant'; $F_Data.AlreadyOkCount++ }
                'NotPresent' { $F_Data["${F_Label}_Action"] = 'NotPresent';       $F_Data.AlreadyOkCount++ }
                default      { $F_Data["${F_Label}_Action"] = "Skipped$F_State" }
            }
            continue
        }

        $F_Data.InScopeCount++

        try
        {
            # New-ItemProperty -Force creates or overwrites, and is the reliable way to
            # pin the value KIND as well as the data. It needs the key to exist first,
            # which is only in question when creating a missing value.
            if (-not (Test-Path -LiteralPath $F_Target.Path))
            {
                New-Item -Path $F_Target.Path -Force -ErrorAction Stop | Out-Null
            }

            New-ItemProperty -LiteralPath $F_Target.Path -Name $F_Target.Name `
                             -Value $F_Target.DesiredData -PropertyType $F_Target.Type `
                             -Force -ErrorAction Stop | Out-Null

            # Verify: a write that returns cleanly but did not take is a failure. Check the
            # kind as well as the data - a value of the wrong kind can still read as equal.
            $F_After = Get-RegistryValueInfo -F_Path $F_Target.Path -F_Name $F_Target.Name

            if ($null -eq $F_After)
            {
                $F_Data.FailedCount++
                $F_Data["${F_Label}_Action"] = 'Failed'
                $F_Data["${F_Label}_Error"]  = 'Value absent after write'
                continue
            }

            $F_Data["${F_Label}_DataNow"] = Format-DataField -F_Text (ConvertTo-ComparableString -F_Data $F_After.Data) -F_MaxLength $S_MaxDataLength

            $F_ExpectedText = ConvertTo-ComparableString -F_Data $F_Target.DesiredData
            $F_ActualText   = ConvertTo-ComparableString -F_Data $F_After.Data

            if ($F_ActualText -ine $F_ExpectedText -or $F_After.Kind.ToString() -ine [string]$F_Target.Type)
            {
                $F_Data.FailedCount++
                $F_Data["${F_Label}_Action"] = 'Failed'
                $F_Data["${F_Label}_Error"]  = "Verification failed: read back $($F_After.Kind) '$F_ActualText', expected $($F_Target.Type) '$F_ExpectedText'"
                continue
            }

            $F_Data.SetCount++
            $F_Data["${F_Label}_Action"] = 'Set'
        }
        catch
        {
            $F_Data.FailedCount++
            $F_Data["${F_Label}_Action"] = 'Failed'
            $F_Data["${F_Label}_Error"]  = Format-DataField -F_Text $_.Exception.Message -F_MaxLength $S_MaxDataLength
        }
    }

    if ($F_Data.InScopeCount -eq 0)
    {
        Write-IntuneResult -F_ScriptType 'Remediation' -F_Status 'NoActionRequired' -F_Data $F_Data `
                           -F_Summary 'Nothing needed remediation by the time this ran; Windows Update is not restricted by policy.'
        exit 0
    }

    if ($F_Data.FailedCount -eq 0)
    {
        Write-IntuneResult -F_ScriptType 'Remediation' -F_Status 'Success' -F_Data $F_Data `
                           -F_Summary "Restored Windows Update: set and verified $($F_Data.SetCount) of $($F_Data.TargetCount) policy value(s) to the desired data."
        exit 0
    }

    if ($F_Data.SetCount -gt 0)
    {
        Write-IntuneResult -F_ScriptType 'Remediation' -F_Status 'PartialSuccess' -F_Data $F_Data `
                           -F_Summary "Set $($F_Data.SetCount) of $($F_Data.InScopeCount) in-scope value(s); $($F_Data.FailedCount) could not be written."
        exit 1
    }

    Write-IntuneResult -F_ScriptType 'Remediation' -F_Status 'Failed' -F_Data $F_Data `
                       -F_Summary "None of the $($F_Data.InScopeCount) in-scope value(s) could be written."
    exit 1
}
catch
{
    # The device is still in its pre-remediation state, so this must be reported as a
    # failed remediation - exit 1, unlike the detection script's error path.
    Write-IntuneResult -F_ScriptType 'Remediation' -F_Status 'Error' -F_Data $F_Data `
                       -F_Summary 'Remediation failed with an unhandled error; Windows Update may still be restricted by policy.' `
                       -F_ErrorMessage $_.Exception.Message
    exit 1
}

#endregion -------------------------------------------------------------------------
