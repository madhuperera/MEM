# Detection script for PDF-XChange old versions
# Intune Win32 App Detection: Exit 0 = detected (old versions found), Exit 1 = not detected (clean)
# Used as detection for the UNINSTALL package — success means old versions still exist and need removal.

[int] $S_KeepMajorVersion = 10

$OldVersions = Get-CimInstance -ClassName Win32_Product -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*PDF-XChange*" } |
    Where-Object {
        try { [int]($_.Version -split '\.')[0] -lt $S_KeepMajorVersion } catch { $true }
    }

if ($null -ne $OldVersions -and @($OldVersions).Count -gt 0)
{
    # Old versions still present — cleanup has not run yet
    foreach ($App in $OldVersions)
    {
        Write-Host "DETECTED: $($App.Name) ($($App.Version))"
    }
    exit 1
}
else
{
    # No old versions found — cleanup is complete
    Write-Host "No PDF-XChange products older than major version $S_KeepMajorVersion found."
    exit 0
}
