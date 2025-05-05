# Detect-Signatures.ps1
# This script checks the user's AppData folder for any files within the Outlook Signatures directory.

# Get the current user's AppData folder
$AppDataPath = $ENV:APPDATA
if (-not $AppDataPath)
{
    Write-Output "Unable to determine the AppData path."
    exit 1
}

# Define the path to the Outlook Signatures folder
$SignaturesPath = Join-Path -Path $AppDataPath -ChildPath "Microsoft\Signatures"

# Check if the Signatures folder exists
if (Test-Path -Path $SignaturesPath)
{
    # Get all files in the Signatures folder
    $SignatureFiles = Get-ChildItem -Path $SignaturesPath -File -Recurse -ErrorAction SilentlyContinue

    if ($SignatureFiles.Count -gt 0)
    {
        Write-Output "Signatures found in the folder:"
        exit 1
    }
    else
    {
        Write-Output "No signature files found in the Outlook Signatures folder."
        exit 0
    }
}
else
{
    Write-Output "The Outlook Signatures folder does not exist."
    exit 0
}