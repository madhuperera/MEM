# ============================================================
# Script Variables
# ============================================================
$ImageName       = "Lockscreen.jpg"
$DestinationPath = "C:\Windows\Web\Screen\$ImageName"
$LogPath         = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Configure-Lockscreen.log"

$RegKeyValuePairs = @(
    @{
        KeyPath   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImagePath"
        ValueData = $DestinationPath
        ValueType = "String"
    },
    @{
        KeyPath   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImageStatus"
        ValueData = 1
        ValueType = "DWord"
    }
)

# ============================================================
# Functions
# ============================================================
Function Set-KeyValueData
{
    param
    (
        [string]$KeyPath,
        [string]$ValueName,
        [string]$ValueData,
        [string]$ValueType
    )

    if (!(Test-Path $KeyPath))
    {
        New-Item -Path $KeyPath -Force | Out-Null
    }
    New-ItemProperty -Path $KeyPath -Name $ValueName -Value $ValueData -PropertyType $ValueType -Force | Out-Null
}

# ============================================================
# Main
# ============================================================
Start-Transcript -Path $LogPath -Force -Append

try
{
    # Copy the lockscreen image to the destination
    $SourcePath = Join-Path -Path $PSScriptRoot -ChildPath $ImageName

    if (Test-Path -Path $SourcePath)
    {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        Write-Host "File copied: $SourcePath -> $DestinationPath"
    }
    else
    {
        Write-Host "Source file not found: $SourcePath"
        Stop-Transcript
        exit 1
    }

    # Remove any unexpected LockScreen-prefixed values under the parent key
    $ParentKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
    $AllowedValues = $RegKeyValuePairs | ForEach-Object { $_.ValueName }

    if (Test-Path -Path $ParentKeyPath)
    {
        $existingValues = Get-Item -Path $ParentKeyPath | Select-Object -ExpandProperty Property
        foreach ($valueName in $existingValues)
        {
            if ($valueName -like "LockScreen*" -and $valueName -notin $AllowedValues)
            {
                try
                {
                    Remove-ItemProperty -Path $ParentKeyPath -Name $valueName -Force -ErrorAction Stop
                    Write-Host "Removed unexpected value: $ParentKeyPath\$valueName"
                }
                catch
                {
                    Write-Host "Failed to remove unexpected value: $ParentKeyPath\$valueName - $_"
                    Stop-Transcript
                    exit 1
                }
            }
        }
    }

    # Set registry key values
    foreach ($Key in $RegKeyValuePairs)
    {
        try
        {
            Set-KeyValueData -KeyPath $Key.KeyPath -ValueName $Key.ValueName -ValueData $Key.ValueData -ValueType $Key.ValueType
            Write-Host "Registry set: $($Key.KeyPath)\$($Key.ValueName) = $($Key.ValueData)"
        }
        catch
        {
            Write-Host "Failed to set: $($Key.KeyPath)\$($Key.ValueName) - $_"
            Stop-Transcript
            exit 1
        }
    }

    Write-Host "Lockscreen configured successfully."
    Stop-Transcript
    exit 0
}
catch
{
    Write-Host "Unexpected error: $_"
    Stop-Transcript
    exit 1
}