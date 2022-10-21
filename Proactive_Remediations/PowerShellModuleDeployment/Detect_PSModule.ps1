[String] $S_PSModuleName = "RunAsUser"
[String] $S_PSModuleMinVersionRequired = "2.3.1"
[String] $S_PSRepository = "PSGallery"
[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
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

function Test-PowerShellModuleStatus
{
    param
    (
        [String] $PSModuleName,
        [String] $PSModuleMinVersionRequired
    )
    
    if (Get-InstalledModule -Name $PSModuleName -MinimumVersion $PSModuleMinVersionRequired -ErrorAction SilentlyContinue)
    {
        return $true
    }
    else
    {
        return $false
    }
}

if (Test-PowerShellModuleStatus -PSModuleName $S_PSModuleName -PSModuleMinVersionRequired $S_PSModuleMinVersionRequired)
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}