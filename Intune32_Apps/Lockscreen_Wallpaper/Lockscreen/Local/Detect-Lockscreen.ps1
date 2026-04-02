# ============================================================
# Script Variables
# ============================================================
$ImageName       = "Lockscreen.jpg"
$DestinationPath = "C:\Windows\Web\Screen\$ImageName"

$RegKeyValuePairs = @(
    @{
        KeyPath   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImagePath"
        ValueData = $DestinationPath
    },
    @{
        KeyPath   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
        ValueName = "LockScreenImageStatus"
        ValueData = 1
    }
)

# ============================================================
# Detection
# ============================================================
try
{
    # Check lockscreen image file exists
    if (!(Test-Path -Path $DestinationPath -PathType Leaf))
    {
        Write-Host "File not found: $DestinationPath"
        exit 1
    }

    # Check all registry key values match
    foreach ($Key in $RegKeyValuePairs)
    {
        if (!(Test-Path -Path $Key.KeyPath))
        {
            Write-Host "Registry path not found: $($Key.KeyPath)"
            exit 1
        }

        $regProperty = Get-ItemProperty -Path $Key.KeyPath -Name $Key.ValueName -ErrorAction SilentlyContinue
        if ($null -eq $regProperty)
        {
            Write-Host "Registry value not found: $($Key.KeyPath)\$($Key.ValueName)"
            exit 1
        }

        $currentValue = $regProperty.$($Key.ValueName)
        if ($currentValue -ne $Key.ValueData)
        {
            Write-Host "Registry mismatch: $($Key.KeyPath)\$($Key.ValueName) = '$currentValue' (expected '$($Key.ValueData)')"
            exit 1
        }
    }

    # Check for unexpected LockScreen-prefixed values under PersonalizationCSP
    $ParentKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
    $AllowedValues = $RegKeyValuePairs | ForEach-Object { $_.ValueName }

    if (Test-Path -Path $ParentKeyPath)
    {
        $existingValues = Get-Item -Path $ParentKeyPath | Select-Object -ExpandProperty Property
        foreach ($valueName in $existingValues)
        {
            if ($valueName -like "LockScreen*" -and $valueName -notin $AllowedValues)
            {
                Write-Host "Unexpected LockScreen value found: $ParentKeyPath\$valueName"
                exit 1
            }
        }
    }

    # Check for stale LockScreen-related values under old GPO path
    $GpoKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"

    if (Test-Path -Path $GpoKeyPath)
    {
        $gpoValues = Get-Item -Path $GpoKeyPath | Select-Object -ExpandProperty Property
        foreach ($valueName in $gpoValues)
        {
            if ($valueName -like "*LockScreen*")
            {
                Write-Host "Stale GPO LockScreen value found: $GpoKeyPath\$valueName"
                exit 1
            }
        }
    }

    Write-Host "Lockscreen detected successfully."
    exit 0
}
catch
{
    Write-Host "Detection error: $_"
    exit 1
}
