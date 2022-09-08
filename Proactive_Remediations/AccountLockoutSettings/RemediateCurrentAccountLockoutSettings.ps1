$S_RequiredAcLOutThreshold = 8

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
function Update-OutputOnExit
{
    param
    (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode)
    {
        exit 1
    }
    else
    {
        exit 0
    }
}

net accounts /lockoutthreshold:$S_RequiredAcLOutThreshold  
$CLine = net accounts | Where-Object {$_ -like "Lockout threshold:*"}
$CurrentAcLOutThreshold = ($CLine -split " ")[-1]

if ($CurrentAcLOutThreshold -ne $S_RequiredAcLOutThreshold)
{
	Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
else
{
	Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
