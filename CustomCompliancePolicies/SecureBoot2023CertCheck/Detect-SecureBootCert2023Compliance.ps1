<#PSScriptInfo
.VERSION        1.0.0
.AUTHOR         Derived from work by @MrTbone_se (T-bone Granheden)
.DESCRIPTION    Extract KEK certificates from SecureBoot and output as JSON
.NOTES
    ATTRIBUTION & FEEDBACK:
    This script is derived from and builds upon the excellent work in Detect-SecureBoot.ps1
    Original Author: @MrTbone_se (T-bone Granheden)
    Original Repository: https://github.com/Mr-Tbone/Intune
    
    FUNCTIONALITY EXTRACTED:
    - Get-SecureBootCertSubjects function (adapted from original)
    - EFI signature database parsing logic
    - X509 certificate extraction and subject handling
    - Certificate Common Name (CN) extraction via regex
    
    MODIFICATIONS IN THIS VERSION:
    This script focuses specifically on KEK (Key Exchange Key) certificate extraction
    and outputs results in JSON format for programmatic consumption.
    The core parsing logic remains faithful to the original implementation.
    
    PROCESS OVERVIEW:
    1. Calls Get-SecureBootCertSubjects -Database kek to retrieve KEK certificates
    2. Pulls raw UEFI variable via (Get-SecureBootUEFI -Name kek).Bytes
    3. Parses the EFI signature database structure
    4. Extracts X509 certificates and reads cert.Subject property
    5. Formats subjects into semicolon-separated string
    6. Shortens each certificate subject to Common Name (CN) using regex CN=(.+?),
    7. Outputs result as JSON with [INFO]SecureBootKEK label
    
    ORIGINAL SCRIPT REFERENCE:
    The original Get-SecureBootCertSubjects function appears in Detect-SecureBoot.ps1
    at lines 289-345 (Get-SecureBootCertSubjects function definition)
    Line 300: $(Get-SecureBootUEFI -Name $Database).Bytes
    Lines 304-333: EFI signature database parsing, X509 cert extraction, subject reading
    Line 224: Original call to Get-SecureBootCertSubjects -Database kek
    Line 225: CN regex extraction: CN=(.+?),
#>

function Get-SecureBootCertSubjects {
<#
.SYNOPSIS
    Parse Secure Boot database signatures and return them as objects
.DESCRIPTION
    Parses the EFI signature database and returns an array of PSCustomObjects representing the signatures.
    Gets the raw UEFI variable via (Get-SecureBootUEFI -Name $Database).Bytes
    Extracts X509 certificates and reads the Subject property
.NOTES
    Version: 1.0.0
    Author:  @MrTbone_se (T-bone Granheden)
#>
    param(
        [Parameter(Mandatory=$true, HelpMessage="Name of the Secure Boot database to parse")]
        [string]$Database
    )
    
    # Get raw UEFI variable - this is line 300 equivalent
    $db = (Get-SecureBootUEFI -Name $Database).Bytes
    
    # Define GUIDs for certificate types
    $EFI_CERT_X509_GUID = [guid]"a5c059a1-94e4-4aa7-87b5-ab155c2bf072"
    $EFI_CERT_SHA256_GUID = [guid]"c1c41626-504c-4092-aca9-41f936934328"
    
    $signatures = @()
    
    # Parse EFI signature database structure (lines 304-333 implementation)
    for ($o = 0; $o -lt $db.Length; ) {
        $guid = [Guid][Byte[]]$db[$o..($o+15)]
        $signatureListSize = [BitConverter]::ToUInt32($db, $o+16)
        $signatureSize = [BitConverter]::ToUInt32($db, $o+24)
        $signatureCount = ($signatureListSize - 28) / $signatureSize
        $so = $o + 28
        
        for ($i = 0; $i -lt $signatureCount; $i++) {
            $signatureOwner = [Guid][Byte[]]$db[$so..($so+15)]
            
            # Extract X509 certificates and read Subject
            if ($guid -eq $EFI_CERT_X509_GUID) {
                $certBytes = $db[($so+16)..($so+16+$signatureSize-1)]
                try {
                    $cert = if ($PSEdition -eq "Core") {
                        [System.Security.Cryptography.X509Certificates.X509Certificate]::new([Byte[]]$certBytes)
                    } else {
                        $c = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                        $c.Import([Byte[]]$certBytes)
                        $c
                    }
                    # Read cert.Subject property for X509 certificates
                    $signatures += [PSCustomObject]@{SignatureOwner=$signatureOwner; SignatureSubject=$cert.Subject; Signature=$cert; SignatureType=$guid}
                } catch {
                    $signatures += [PSCustomObject]@{SignatureOwner=$signatureOwner; SignatureSubject="Failed to parse cert"; Signature=$null; SignatureType=$guid}
                }
            } elseif ($guid -eq $EFI_CERT_SHA256_GUID) {
                $sha256Hash = ([Byte[]]$db[($so+16)..($so+47)] | ForEach-Object { $_.ToString('X2') }) -join ''
                $signatures += [PSCustomObject]@{SignatureOwner=$signatureOwner; Signature=$sha256Hash; SignatureType=$guid}
            } else { 
                $unknownData = [Byte[]]$db[($so+16)..($so+16+$signatureSize-1)]
                $signatures += [PSCustomObject]@{SignatureOwner=$signatureOwner; SignatureSubject="Unknown signature type"; Signature=$unknownData; SignatureType=$guid}
            }
            $so += $signatureSize
        }
        $o += $signatureListSize
    }
    
    return $signatures
}

try {
    # Call Get-SecureBootCertSubjects -Database kek (line 224 equivalent)
    $KEKcerts = Get-SecureBootCertSubjects -Database kek
    
    # Extract KEK version from certificate subjects
    $KEKVersion = $null
    
    if ($KEKcerts) {
        foreach ($cert in $KEKcerts) {
            $subject = $cert.SignatureSubject
            
            # Look for "Microsoft Corporation KEK CA XXXX" and extract the year
            if ($subject -match 'Microsoft Corporation KEK CA (\d{4})') {
                $KEKVersion = $matches[1]
                break
            }
        }
    }
    
    # If no version found, set as unknown
    if (-not $KEKVersion) {
        $KEKVersion = "unknown"
    }
    
    # Call Get-SecureBootCertSubjects -Database db to retrieve SecureBootDB
    $DBcerts = Get-SecureBootCertSubjects -Database db
    
    # Extract DB version from certificate subjects
    # Look for either "Microsoft Corporation UEFI CA" or "Microsoft Windows Production PCA"
    $DBVersions = @()
    
    if ($DBcerts) {
        foreach ($cert in $DBcerts) {
            $subject = $cert.SignatureSubject
            
            # Look for "Microsoft Corporation UEFI CA XXXX" or "Microsoft Windows Production PCA XXXX" and extract the year
            if ($subject -match 'Microsoft Corporation UEFI CA (\d{4})') {
                $DBVersions += [int]$matches[1]
            }
            elseif ($subject -match 'Microsoft Windows Production PCA (\d{4})') {
                $DBVersions += [int]$matches[1]
            }
        }
    }
    
    # If versions found, return the oldest (minimum) year, otherwise set as unknown
    if ($DBVersions.Count -gt 0) {
        $DBVersion = ($DBVersions | Measure-Object -Minimum).Minimum.ToString()
    } else {
        $DBVersion = "unknown"
    }
    
    # Check if DB has Windows UEFI CA 2023 certificate (from Detect-SecureBoot.ps1 line 227)
    $DBHas2023 = [bool] ($DBcerts | Where-Object { $_.SignatureSubject -match 'Windows UEFI CA 2023' })
    
    # Output as simple JSON with detected values
    $hash = @{
        SecureBootKEK = $KEKVersion
        SecureBootDB = $DBVersion
        SecureBootDBHas2023 = $DBHas2023.ToString().ToLower()
    }
    return $hash | ConvertTo-Json -Compress
}
catch {
    $hash = @{
        SecureBootKEK = "error"
        SecureBootDB = "error"
        SecureBootDBHas2023 = "false"
    }
    return $hash | ConvertTo-Json -Compress
    exit 1
}