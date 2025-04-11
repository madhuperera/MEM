[string]$ModuleName = "BurntToast"
[string]$MinimumVersion = "0.8.5"


# Install the module for all users
try
{
    Install-Module -Name $ModuleName -RequiredVersion $MinimumVersion -Scope AllUsers -Force -AllowClobber
    Write-Host "Module '$ModuleName' (version $MinimumVersion or higher) installed successfully for all users."
    exit 0
}
catch
{
    Write-Error "Failed to install module '$ModuleName'. Error: $_"
    exit 1
}
