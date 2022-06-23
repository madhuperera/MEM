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

# [bool] $ExitWithError = $true
# [bool] $ExitWithNoError = $false

# FAILURE --> Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
# SUCCESS --> Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"