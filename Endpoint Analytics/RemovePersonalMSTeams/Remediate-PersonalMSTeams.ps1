$App  = 'MicrosoftTeams'
$Package = Get-AppxPackage | Where-Object {$_.Name -eq $App}
Remove-AppxPackage -Package $Package.PackageFullName

$Package = Get-AppxPackage | Where-Object {$_.Name -eq $App}
If ($null -ne $Package)
{
    write-host "Failed to remove the app"
 	exit 1
}
else
{
 	write-host "App successfully removed"
 	exit 0
}
