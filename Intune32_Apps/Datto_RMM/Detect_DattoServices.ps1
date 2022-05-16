If (Get-Service CagService -ErrorAction SilentlyContinue)
{
    write-host '<-Start Result->'
    write-host "STDOUT=Datto Service is already running"
    write-host '<-End Result->'
    exit 0
}
else
{
    write-host '<-Start Result->'
    write-host "STDOUT=Datto Service is Not Running"
    write-host '<-End Result->'
    exit 1
}