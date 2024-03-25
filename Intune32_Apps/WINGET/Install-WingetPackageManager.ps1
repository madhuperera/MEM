[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
[string] $WingetPManagerLocation = "C:\ProgramData\WinGetPackages"

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

if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller)
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else 
{
    try
    {
        if (!(Test-Path -Path $WingetPManagerLocation))
        {
            New-Item -Path $WingetPManagerLocation -Force -ItemType Directory -ErrorAction Stop
        }

        Set-Location $WingetPManagerLocation

        #Microsoft.UI.Xaml
        Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0" -OutFile "$WingetPManagerLocation\microsoft.ui.xaml.latest.zip"
        Expand-Archive "$WingetPManagerLocation\microsoft.ui.xaml.latest.zip" -Force

        #Microsoft.VCLibs.140.00.UWPDesktop
        Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "$WingetPManagerLocation\Microsoft.VCLibs.x64.14.00.Desktop.appx"

        #Winget
        Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "$WingetPManagerLocation\Winget.msixbundle"
        
        #Installing dependencies + Winget
        [string] $UIXMLFileName = (Get-ChildItem -Path ".\microsoft.ui.xaml.latest\tools\AppX\x64\Release\Microsoft.UI.Xaml*.appx").Name
        Add-ProvisionedAppxPackage -online -PackagePath:.\Winget.msixbundle -DependencyPackagePath .\Microsoft.VCLibs.x64.14.00.Desktop.appx,.\microsoft.ui.xaml.latest\tools\AppX\x64\Release\$UIXMLFileName -SkipLicense
    }
    catch
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}

Start-Sleep -Seconds 120
if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller)
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
