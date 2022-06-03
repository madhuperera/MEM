# ---------------------------------------------------------------------------- #
# Set Generic Script Variables, etc.
# ---------------------------------------------------------------------------- #

# List of Applications to Remove
$App  = 'MicrosoftTeams'


$Package = Get-AppxPackage | Where-Object {$_.Name -eq $App}
# $ProvisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $App}
If ($null -ne $Package)
{
    write-host "STATUS=Teams Personal App Found"
 	exit 1
}
else
{
 	write-host "STATUS=All Good"
 	exit 0
}
