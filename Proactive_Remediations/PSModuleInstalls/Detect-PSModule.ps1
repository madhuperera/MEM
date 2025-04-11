[string]$ModuleName = "BurntToast"
[string]$MinimumVersion = "0.8.5"

$CurrentInstall = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue

if ($CurrentInstall)
{
    $CurrentVersion = $CurrentInstall.Version.ToString()
    if ($CurrentVersion -ge $MinimumVersion)
    {
        Write-Host "Module '$ModuleName' (version $CurrentVersion) is already installed."
        exit 0
    }
    else
    {
        Write-Host "Module '$ModuleName' (version $CurrentVersion) is installed but not the required version ($MinimumVersion)."
        exit 1
    }
}
else
{
    Write-Host "Module '$ModuleName' is not installed."
    exit 1
}