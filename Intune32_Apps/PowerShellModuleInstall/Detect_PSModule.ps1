[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
[string] $SPS_PackagerProviderName = "NuGet" # Please change this
[String] $SPS_ModuleName = "BurntToast" # Please change this
[String] $SPS_ModuleVersionRequired = "0.8.5" # Please change this

[ValidateSet("AllUsers","CurrentUser")] $SPS_InstallScope = "AllUsers" # Please change this

function Update-OutputOnExit
{
    param
    (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode)
    {
        exit 1
    }
    else
    {
        exit 0
    }
}

function Get-PackageProviderStatus
{
    param
    (
        [String] $F_PackageProviderName
    )
    
    if (Get-PackageProvider -ListAvailable | Where-Object {$_.Name -eq $F_PackageProviderName})
    {
        return $true
    }
    else
    {
        return $false
    }
}

if ((!(Get-PackageProviderStatus -F_PackageProviderName $SPS_PackagerProviderName)) -or (!(Get-Module -ListAvailable | Where-Object {($_.Name -eq $SPS_ModuleName)})))
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED" 
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}