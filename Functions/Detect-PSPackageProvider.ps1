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
