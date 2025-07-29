# ByAppVersion.ps1

param()

$AppName = "ScreenConnect Client*"        # e.g., "*Google Chrome*"
$RequiredVersion = "25.4.20.9295"    # e.g., "120.0.6099.110"
$CheckVersion = $true           # $true or $false

# --- Exit Codes ---
$EXIT_APP_NOT_FOUND = 1
$EXIT_VERSION_TOO_LOW = 2
$EXIT_SUCCESS = 0
$EXIT_ERROR = 99

try
{
    # Get installed apps using Get-Package
    $apps = Get-Package -ErrorAction SilentlyContinue

    # Find the app
    $app = $apps | Where-Object { $_.Name -like $AppName}

    if (-not $app)
    {
        Write-Output "Application '$AppName' not found."
        exit $EXIT_APP_NOT_FOUND
    }

    if ($CheckVersion)
    {
        $installedVersion = $app.Version
        if (-not $installedVersion)
        {
            Write-Output "Version information not found for '$AppName'."
            exit $EXIT_VERSION_TOO_LOW
        }
        if ([version]$installedVersion -lt [version]$RequiredVersion)
        {
            Write-Output "Installed version ($installedVersion) is lower than required ($RequiredVersion)."
            exit $EXIT_VERSION_TOO_LOW
        }
    }

    Write-Output "Application '$AppName' is installed and meets version requirements."
    exit $EXIT_SUCCESS
}
catch
{
    Write-Error "An error occurred: $_"
    exit $EXIT_ERROR
}
