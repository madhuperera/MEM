# Detect-Signatures.ps1
# This script checks the user's AppData folder for the Outlook Signatures directory
# and performs renaming and cleanup operations as specified.

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
if (-not (Test-Path -Path $SignaturesPath))
{
    Write-Output "The Outlook Signatures folder does not exist."
    exit 0
}

# Define the path to the Signatures.bak folder
$SignaturesBakPath = Join-Path -Path $AppDataPath -ChildPath "Microsoft\Signatures.bak"

# Check if there are any files or folders in the Signatures folder
$SignatureItems = Get-ChildItem -Path $SignaturesPath -Recurse -ErrorAction SilentlyContinue
if (-not $SignatureItems)
{
    Write-Output "No items found in the Outlook Signatures folder."
    exit 0
}

# If Signatures.bak exists, rename it to Signatures.old
if (Test-Path -Path $SignaturesBakPath)
{
    $SignaturesOldPath = Join-Path -Path $AppDataPath -ChildPath "Microsoft\Signatures.old"
    Rename-Item -Path $SignaturesBakPath -NewName $SignaturesOldPath -Force
}

# Rename Signatures to Signatures.bak
Rename-Item -Path $SignaturesPath -NewName $SignaturesBakPath -Force

# Delete Signatures.old if it exists
if (Test-Path -Path $SignaturesOldPath)
{
    Remove-Item -Path $SignaturesOldPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "Signatures folder has been renamed to Signatures.bak, and Signatures.old has been cleaned up."
exit 0