# Import the BurntToast module
Import-Module BurntToast -ErrorAction Stop

# Define global variables
$RebootTime = (Get-Date).AddHours(2)
$SnoozeDuration = 30 # in minutes
$CountdownStart = 15 # in minutes

# Function to show a toast notification
function Show-ToastNotification {
    param (
        [string]$Title,
        [string]$Message,
        [string]$SnoozeAction,
        [string]$RebootAction
    )

    # Create the toast notification with actions
    New-BurntToastNotification -Text $Title, $Message -Button @(
        New-BTButton -Content "Snooze" -Arguments "$SnoozeAction",
        New-BTButton -Content "Reboot Now" -Arguments "$RebootAction"
    )
}

# Function to handle snooze action
function Handle-Snooze {
    $Global:RebootTime = $RebootTime.AddMinutes($SnoozeDuration)
    Show-ToastNotification -Title "Reboot Snoozed" -Message "Reboot postponed by $SnoozeDuration minutes. New reboot time: $RebootTime." -SnoozeAction "snooze" -RebootAction "reboot"
}

# Function to handle reboot action
function Handle-Reboot {
    Stop-Countdown
    Restart-Computer -Force
}

# Function to start the countdown
function Start-Countdown {
    while ((Get-Date) -lt $RebootTime) {
        $TimeRemaining = ($RebootTime - (Get-Date)).TotalMinutes
        if ($TimeRemaining -le $CountdownStart) {
            Show-ToastNotification -Title "Reboot Countdown" -Message "Reboot in $([math]::Floor($TimeRemaining)) minutes." -SnoozeAction "none" -RebootAction "none"
            Start-Sleep -Seconds 60
        } else {
            Start-Sleep -Seconds 60
        }
    }
    Handle-Reboot
}

# Function to stop the countdown (e.g., if the device reboots early)
function Stop-Countdown {
    Write-Output "Countdown stopped."
}

# Main logic
Show-ToastNotification -Title "Scheduled Reboot" -Message "Your device will reboot in 2 hours. Click Snooze to postpone by 30 minutes." -SnoozeAction "snooze" -RebootAction "reboot"
Start-Countdown