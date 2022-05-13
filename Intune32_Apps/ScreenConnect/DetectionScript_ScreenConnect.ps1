[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

function Get-ScreenConnectInstallStatus()
{
    $64bit_Installed = Get-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -ilike 'screenconnect client*' }
    $32bit_Installed = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -ilike 'screenconnect client*' }
    
    
    return $null -ne $64bit_Installed -or $null -ne $32bit_Installed
}

if (Get-ScreenConnectInstallStatus)
{
    Write-Output "ScreenConnect is already installed"
    exit $ExitWithNoError
}
else
{
    Write-Output "ScreenConnect is NOT installed"
    exit $ExitWithError
}