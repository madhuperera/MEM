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
            write-host "STATUS=All Good"
 	        exit 0
        }
        else
        {
            write-host "STATUS=Taskbar is not Left Aligned"
            exit 1
        }
    }
    else
    {
        write-host "STATUS=Registry Key is missing"
        exit 1
    }
}
