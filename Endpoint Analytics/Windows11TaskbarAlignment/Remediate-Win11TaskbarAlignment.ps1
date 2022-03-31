# ---------------------------------------------------------------------------- #
# Set Generic Script Variables, etc.
# ---------------------------------------------------------------------------- #

# List of Applications to Remove
$RegKeyName  = 'TaskbarAl'
$RegKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'


if (Test-Path -Path $RegKeyPath)
{
    $RegKeyAssignement = Get-ItemProperty -Path $RegKeyPath -Name $RegKeyName -ErrorAction SilentlyContinue
    if ($RegKeyAssignement)
    {
        if ($RegKeyAssignement.TaskbarAl -eq 0)
        {
            write-host "STATUS=Taskbar is already aligned Left"
 	        exit 0
        }
        else
        {
            New-ItemProperty -Path $RegKeyPath -Name $RegKeyName -PropertyType DWord -Value 0 -Force | Out-Null
            write-host "STATUS=Updated Taskbar Settings"
 	        exit 0
        }
    }
    else
    {
        New-ItemProperty -Path $RegKeyPath -Name $RegKeyName -PropertyType DWord -Value 0 -Force | Out-Null
            write-host "STATUS=Created and Updated Taskbar Settings"
 	        exit 0
    }
}