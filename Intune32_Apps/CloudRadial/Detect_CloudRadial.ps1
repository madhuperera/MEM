If (Get-Service CloudRadial -ErrorAction SilentlyContinue)
{
    write-host '<-Start Result->'
    write-host "STDOUT=CloudRadial Service is already running"
    write-host '<-End Result->'
    exit 0
}
else
{
    write-host '<-Start Result->'
    write-host "STDOUT=CloudRadial Service is Not Running"
    write-host '<-End Result->'
    exit 1
}