$params = "/X{9E497A7E-26BE-4BA3-AF58-071D8D700DA7} /Quiet"
$media_path = "C:\Windows\System32\msiexec.exe"

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

function Test-PendingReboot
{
    # Check PendingFileRenameOperations
    $PendingFileRenameOperations = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if ($PendingFileRenameOperations -ne $null)
    {
        return $true
    }

    # Check Windows Update RebootRequired
    $RebootRequired = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
    if ($RebootRequired -ne $null)
    {
        return $true
    }

    # Check Component Based Servicing (CBS) RebootPending
    $CBSRebootPending = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
    if ($CBSRebootPending -ne $null)
    {
        return $true
    }

    return $false
}

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

if (Test-PendingReboot)
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED:SYS_PENDING_REBOOT"
}
else
{
    try
    {
        Start-Process -FilePath $media_path -ArgumentList $params -Wait -ErrorAction Stop
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    catch
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}