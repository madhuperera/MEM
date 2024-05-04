# This app is dependent on WINGET Package Manager: https://github.com/madhuperera/MEM/tree/a6bf94109d3f4ff1f537aa1efa9e1b35f6a66fa6/Intune32_Apps/WINGET

[String] $S_WingetAppID = "Notepad\+\+.Notepad\+\+"

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

function Test-WingetPackageManagerInstalled
{
    if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller)
    {
        return $true
    }
    else 
    {
        return $false
    }
}


function Test-WingetAppInstalled
{
    # Name of the Application
    param 
    (
        [string] $F_WingetAppId
    )

    [string] $WingetPInstallerPath = (Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction Stop)[-1].Path
    if ($WingetPInstallerPath)
    {
        Set-Location -Path $WingetPInstallerPath -ErrorAction Stop
        if ((.\winget.exe list $F_WingetAppId) -match $F_WingetAppId)
        {
            return $true
        }
        else
        {
            return $false
        }    
    }
    else
    {
        return $false
    }    
}

if (!(Test-WingetPackageManagerInstalled))
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
else
{
    if (Test-WingetAppInstalled -F_WingetAppId $S_WingetAppID)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    else
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}
