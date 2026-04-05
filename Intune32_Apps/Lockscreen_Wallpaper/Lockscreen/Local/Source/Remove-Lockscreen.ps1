# ============================================================
# Script Variables
# ============================================================
$ImageName       = "Lockscreen.jpg"
$DestinationPath = "C:\Windows\Web\Screen\$ImageName"
$LogPath         = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Remove-Lockscreen.log"

$RegKeyValuePairs = @(
    @{
        KeyPath   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImagePath"
    },
    @{
        KeyPath   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImageStatus"
    }
)

# ============================================================
# Main
# ============================================================
Start-Transcript -Path $LogPath -Force -Append

try
{
    # Remove registry key values
    foreach ($Key in $RegKeyValuePairs)
    {
        try
        {
            if (Test-Path $Key.KeyPath)
            {
                $existing = Get-ItemProperty -Path $Key.KeyPath -Name $Key.ValueName -ErrorAction SilentlyContinue
                if ($existing)
                {
                    Remove-ItemProperty -Path $Key.KeyPath -Name $Key.ValueName -Force -ErrorAction Stop
                    Write-Host "Removed: $($Key.KeyPath)\$($Key.ValueName)"
                }
                else
                {
                    Write-Host "Already absent: $($Key.KeyPath)\$($Key.ValueName)"
                }
            }
            else
            {
                Write-Host "Key path not found: $($Key.KeyPath)"
            }
        }
        catch
        {
            Write-Host "Failed to remove: $($Key.KeyPath)\$($Key.ValueName) - $_"
            Stop-Transcript
            exit 1
        }
    }

    # Remove the lockscreen image file
    if (Test-Path -Path $DestinationPath -PathType Leaf)
    {
        Remove-Item -Path $DestinationPath -Force -ErrorAction Stop
        Write-Host "Removed file: $DestinationPath"
    }
    else
    {
        Write-Host "File already absent: $DestinationPath"
    }

    Write-Host "Lockscreen removal completed successfully."
    Stop-Transcript
    exit 0
}
catch
{
    Write-Host "Unexpected error: $_"
    Stop-Transcript
    exit 1
}