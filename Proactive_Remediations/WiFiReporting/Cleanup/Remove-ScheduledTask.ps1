$S_TaskName = "WiFi_Analysis_v1"
$S_TaskPath = "\"


function Remove-ScheduledTaskIfExists
{
    param
    (
        [String] $TaskName,
        [String] $TaskPath
    )

    [bool] $returnStatus = $true

    try
    {
        # Check if the task exists
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop
        if ($task)
        {
            # Delete the task
            Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false -ErrorAction Stop
            Write-Output "Scheduled task '$TaskName' at path '$TaskPath' has been deleted."
        }
        else
        {
            Write-Output "Scheduled task '$TaskName' at path '$TaskPath' does not exist."
        }
    }
    catch
    {
        Write-Output "An error occurred: $_"
        $returnStatus = $false
    }

    return $returnStatus
}


if (Remove-ScheduledTaskIfExists -TaskName $S_TaskName -TaskPath $S_TaskPath)
{
    Write-Output "$S_TaskName was successfully removed"
    exit 0
}
else
{
    Write-Output "$S_TaskName could not be removed"
    exit 1
}
