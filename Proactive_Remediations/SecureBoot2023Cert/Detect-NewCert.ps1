# Define registry paths
$servicingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
$rootPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot"

$servicingValues = @(
	"UEFICA2023Status",
	"WindowsUEFICA2023Capable",
	"UEFICA2023Error",
	"UEFICA2023ErrorEvent"
)

$rootValues = @(
	"AvailableUpdates"
)

$outputs = New-Object System.Collections.Generic.List[string]
$exitCode = 0

# Function to get registry values
function Get-RegValueOrMissing {
	param (
		[string]$Path,
		[string]$Name
	)

	try {
		if (-not (Test-Path -Path $Path)) {
			return "${Path}:${Name} = <path not present>"
		}

		$value = Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
		return "${Path}:${Name} = $value"
	}
	catch {
		return "${Path}:${Name} = <value not present>"
	}
}

# Function to parse Secure Boot certificates
function Get-SecureBootCertSubjects {
	param(
		[Parameter(Mandatory=$true)]
		[string]$Database
	)
	
	try {
		$db = (Get-SecureBootUEFI -Name $Database).Bytes
		
		$EFI_CERT_X509_GUID = [guid]"a5c059a1-94e4-4aa7-87b5-ab155c2bf072"
		$EFI_CERT_SHA256_GUID = [guid]"c1c41626-504c-4092-aca9-41f936934328"
		
		$signatures = @()
		
		for ($o = 0; $o -lt $db.Length; ) {
			$guid = [Guid][Byte[]]$db[$o..($o+15)]
			$signatureListSize = [BitConverter]::ToUInt32($db, $o+16)
			$signatureSize = [BitConverter]::ToUInt32($db, $o+24)
			$signatureCount = ($signatureListSize - 28) / $signatureSize
			$so = $o + 28
			
			for ($i = 0; $i -lt $signatureCount; $i++) {
				$signatureOwner = [Guid][Byte[]]$db[$so..($so+15)]
				
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
	catch {
		return $null
	}
}

try {
	# Collect registry values
	foreach ($name in $servicingValues) {
		$outputs.Add((Get-RegValueOrMissing -Path $servicingPath -Name $name))
	}

	foreach ($name in $rootValues) {
		$outputs.Add((Get-RegValueOrMissing -Path $rootPath -Name $name))
	}

	# Get Secure Boot certificate values
	$outputs.Add("--- Secure Boot Certificate Check ---")
	
	# Get KEK certificates
	$KEKcerts = Get-SecureBootCertSubjects -Database kek
	$KEKVersion = $null
	
	if ($KEKcerts) {
		foreach ($cert in $KEKcerts) {
			$subject = $cert.SignatureSubject
			if ($subject -match 'Microsoft Corporation KEK CA (\d{4})') {
				$KEKVersion = $matches[1]
				break
			}
		}
	}
	
	if (-not $KEKVersion) {
		$KEKVersion = "unknown"
	}
	$outputs.Add("SecureBootKEK = $KEKVersion")
	
	# Get DB certificates
	$DBcerts = Get-SecureBootCertSubjects -Database db
	$DBVersions = @()
	
	if ($DBcerts) {
		foreach ($cert in $DBcerts) {
			$subject = $cert.SignatureSubject
			if ($subject -match 'Microsoft Corporation UEFI CA (\d{4})') {
				$DBVersions += [int]$matches[1]
			}
			elseif ($subject -match 'Microsoft Windows Production PCA (\d{4})') {
				$DBVersions += [int]$matches[1]
			}
		}
	}
	
	if ($DBVersions.Count -gt 0) {
		$DBVersion = ($DBVersions | Measure-Object -Minimum).Minimum.ToString()
	} else {
		$DBVersion = "unknown"
	}
	$outputs.Add("SecureBootDB = $DBVersion")
	
	# Check if DB has Windows UEFI CA 2023
	$DBHas2023 = [bool] ($DBcerts | Where-Object { $_.SignatureSubject -match 'Windows UEFI CA 2023' })
	$outputs.Add("SecureBootDBHas2023 = $($DBHas2023.ToString().ToLower())")
	
	# Validation: Check if all values meet compliance requirements
	$outputs.Add("--- Compliance Check ---")
	
	if ($KEKVersion -eq "2023" -and $DBVersion -eq "2023" -and $DBHas2023 -eq $true) {
		$outputs.Add("Status = COMPLIANT")
		$exitCode = 0
	} else {
		$outputs.Add("Status = NON-COMPLIANT")
		$outputs.Add("Reason: KEKVersion=$KEKVersion (expected 2023), DBVersion=$DBVersion (expected 2023), DBHas2023=$($DBHas2023.ToString().ToLower()) (expected true)")
		$exitCode = 1
	}
}
catch {
	$outputs.Add("--- ERROR ---")
	$outputs.Add("Error occurred: $($_.Exception.Message)")
	$exitCode = 1
}

# Output all results at once
Write-Output ($outputs -join "`n")

exit $exitCode
