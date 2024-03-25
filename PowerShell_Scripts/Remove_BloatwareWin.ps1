param
(
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "TestName"
)

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

# Keep the List below up to date
$ThirdPartyBloatware = @(
    "*.AmazonAlexa"
    "*.McAfeeSecurity"
    "DropboxOEM"

)

$DellBloatware = @(
    "*.DellMobileConnectPlus"
    "DellInc.DellCinemaGuide"
    "DellInc.DellCustomerConnect"
    "DellInc.DellDigitalDelivery"
    "DellInc.MyDell"
    "DellInc.PartnerPromo"
    "PortraitDisplays.DellCinemaColor"    
)

$MicrosoftBloatware = @(
    "Microsoft.MixedReality.Portal"
    "Microsoft.SkypeApp"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "MicrosoftTeams"
)

function Start-ScriptLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_LogDirectory = "C:\ProgramData\$($F_CompanyName)IntuneManaged\Logs\$F_ScriptName",
        [String] $F_LogName = "Logs.txt",
        [String] $F_LogPath = "$F_LogDirectory\$F_LogName"
    )
    
    Start-Transcript -Path $F_LogPath -Force -Append
}

Start-ScriptLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName
function Update-CustomLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_Message,        
        [String] $F_LogDirectory = "C:\ProgramData\$($F_CompanyName)IntuneManaged\Logs\$F_ScriptName",
        [String] $F_CustomLogName = "RemoveBloatWare.txt",
        [String] $F_CustomLogPath = "$F_LogDirectory\$F_CustomLogName"
    )
    
    [String] $TimeStamp = Get-Date -Format "yyyy-MM-dd-HH:mm:ss__"

    [String] $LogEntry = $TimeStamp + $F_Message
    $LogEntry | Out-File -FilePath $F_CustomLogPath -Append -Force -ErrorAction SilentlyContinue
}

Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "Starting Custom Log"
function Update-OutputOnExit
{
    param
    (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode)
    {
        exit 1
    }
    else
    {
        exit 0
    }
}



# Removing Dell Bloatware
foreach ($Item in $DellBloatware)
{
    $App = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like $Item} -ErrorAction SilentlyContinue
    if ($App)
    {
        Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "Attempting to Remove $($App.DisplayName)"
        $App | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
    else
    {
        Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "$Item not installed)"
    }
}

# Removing 3rd Party Bloatware
foreach ($Item in $ThirdPartyBloatware)
{
    $App = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like $Item} -ErrorAction SilentlyContinue
    if ($App)
    {
        Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "Attempting to Remove $($App.DisplayName)"
        $App | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
    else
    {
        Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "$Item not installed)"
    }
}

# Removing Microsoft Bloatware
foreach ($Item in $MicrosoftBloatware)
{
    $App = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like $Item} -ErrorAction SilentlyContinue
    if ($App)
    {
        Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "Attempting to Remove $($App.DisplayName)"
        $App | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
    else
    {
        Update-CustomLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName -F_Message "$Item not installed)"
    }
}


Stop-Transcript
Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"