# Define the application name as a variable with wildcards
$S_AppName = "*7-Zip*"
$S_RegPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"

# Define the time threshold and increment in seconds
$S_TimeThreshold = 600  # Maximum wait time of 60 seconds
$S_TimeIncrement = 60   # Check every 5 seconds

# Function to test if the app is installed
function Test-AppInstalled
{
    param
    (
        [string]$F_AppName
    )
    $F_AppFound = $false

    try 
    {
        Get-ChildItem -Path $S_RegPath | ForEach-Object 
        {
            $F_DisplayName = (Get-ItemProperty -Path $_.PSPath).DisplayName
            if ($F_DisplayName -like $F_AppName)
            {
                $F_AppFound = $true
                return $F_AppFound
            }
        }
    }
    catch 
    {
        Write-Output "Error accessing registry: $_"
        exit 2  # Error occurred
    }

    return $F_AppFound
}

# Function to get the uninstall string(s)
function Get-AppUninstallString
{
    param(
        [string]$F_AppName
    )
    $F_UninstallStrings = @()

    try 
    {
        Get-ChildItem -Path $S_RegPath | ForEach-Object 
        {
            $F_DisplayName = (Get-ItemProperty -Path $_.PSPath).DisplayName
            if ($F_DisplayName -like $F_AppName)  # Using -like for wildcard search
            {
                $F_UninstallStrings += (Get-ItemProperty -Path $_.PSPath).UninstallString
            }
        }
    }
    catch 
    {
        Write-Output "Error accessing registry: $_"
        exit 2  # Error occurred
    }

    return $F_UninstallStrings
}

# Check if the app is installed
$F_AppInstalled = Test-AppInstalled -F_AppName $S_AppName

# Exit code logic for finding the app
if ($F_AppInstalled) 
{
    Write-Output "Application matching '$S_AppName' found."

    # Attempt to get the uninstall string(s)
    $F_UninstallStrings = Get-AppUninstallString -F_AppName $S_AppName

    if ($F_UninstallStrings.Count -gt 0) 
    {
        Write-Output "Uninstall string(s) found: $($F_UninstallStrings -join ', ')"
        
        # Loop through each uninstall string and attempt uninstallation
        foreach ($F_UninstallString in $F_UninstallStrings) 
        {
            try 
            {
                Write-Output "Uninstalling using string: $F_UninstallString"
                Start-Process -FilePath $F_UninstallString -ArgumentList "/uninstall", "/quiet" -Wait
            } 
            catch 
            {
                Write-Output "Error during uninstallation with string '$F_UninstallString': $_"
            }
        }
        
        # Variable to keep track of how much time has passed
        $F_ElapsedTime = 0

        # Initial check to see if the app is still installed after attempting uninstallation
        $F_AppInstalledAfter = Test-AppInstalled -F_AppName $S_AppName

        # Check in a loop until the app is uninstalled or the time threshold is reached
        while ($F_ElapsedTime -lt $S_TimeThreshold -and $F_AppInstalledAfter) 
        {
            Write-Output "Application still installed, waiting for $S_TimeIncrement seconds..."
            Start-Sleep -Seconds $S_TimeIncrement
            $F_ElapsedTime += $S_TimeIncrement

            # Check again if the app is still installed
            $F_AppInstalledAfter = Test-AppInstalled -F_AppName $S_AppName
        }

        # If the app was successfully uninstalled within the threshold
        if (-not $F_AppInstalledAfter) 
        {
            Write-Output "Application successfully uninstalled."
            exit 0  # Success
        }
        else 
        {
            Write-Output "Failed to uninstall the application within the time threshold of $S_TimeThreshold seconds."
            exit 2  # Uninstallation failed
        }

    }
    else 
    {
        Write-Output "No uninstall string(s) found, but the application is installed."
        exit 1
    }
} 
else 
{
    Write-Output "Application matching '$S_AppName' not found."
    exit 0  # App not found
}
