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
