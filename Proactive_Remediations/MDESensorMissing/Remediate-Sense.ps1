# Remediation Script: Install the Microsoft.Windows.Sense.Client capability

# Define the log file location for capturing DISM output
$LogFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\SenseCapabilityInstall.log"

try 
{
    # Run the DISM command to add the Microsoft.Windows.Sense.Client capability
    $Process = Start-Process -FilePath "dism.exe" `
        -ArgumentList "/online", "/Add-Capability", "/CapabilityName:Microsoft.Windows.Sense.Client~~~~" `
        -PassThru -Wait -NoNewWindow -RedirectStandardOutput $LogFile

    # Check the exit code of the DISM process
    if ($Process.ExitCode -eq 0) 
    {
        Write-Output "Microsoft.Windows.Sense.Client capability was successfully installed."
        Exit 0
    }
    else 
    {
        Write-Output "Failed to install Microsoft.Windows.Sense.Client capability. Exit Code: $($Process.ExitCode)"
        Exit 1
    }
}
catch 
{
    # Handle errors thrown by the Start-Process command
    Write-Output "An error occurred while attempting to install Microsoft.Windows.Sense.Client capability."
    Write-Output $_.Exception.Message
    Exit 1
}
