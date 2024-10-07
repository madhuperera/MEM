# Define the application name as a variable with wildcards
$S_AppName = "*OneLaunch*"
$S_RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"

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
        Get-ChildItem -Path $S_RegPath | ForEach-Object `
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
    param
    (
        [string]$F_AppName
    )
    $F_UninstallStrings = @()

    try 
    {
        Get-ChildItem -Path $S_RegPath | ForEach-Object `
        {
            $F_DisplayName = (Get-ItemProperty -Path $_.PSPath).DisplayName
            if ($F_DisplayName -like $F_AppName)
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
    }
    else 
    {
        Write-Output "No uninstall string(s) found, but the application is installed."
    }

    exit 1  # App found
} 
else 
{
    Write-Output "Application matching '$S_AppName' not found."
    exit 0  # App not found
}
