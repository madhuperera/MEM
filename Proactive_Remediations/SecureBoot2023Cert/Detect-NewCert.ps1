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

foreach ($name in $servicingValues) {
	$outputs.Add((Get-RegValueOrMissing -Path $servicingPath -Name $name))
}

foreach ($name in $rootValues) {
	$outputs.Add((Get-RegValueOrMissing -Path $rootPath -Name $name))
}

Write-Output ($outputs -join "`n")

$status = $null
try {
	if (Test-Path -Path $servicingPath) {
		$status = Get-ItemPropertyValue -Path $servicingPath -Name "UEFICA2023Status" -ErrorAction Stop
	}
}
catch {
	$status = $null
}

if ($status -eq "Updated") {
	exit 0
}

exit 1
