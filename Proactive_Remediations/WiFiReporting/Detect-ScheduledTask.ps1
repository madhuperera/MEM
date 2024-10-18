$S_TaskName = "WiFi_Analysis_v1"
$S_TaskPath = "\"
$S_RepInterval = "PT15M"
$S_RepDuration = "PT8H"

function Test-ScheduledTaskDetails
{
    param
    (
        [String] $TaskName,
        [String] $TaskPath,
        [String] $RepInterval,
        [String] $RepDuration

    )

    [bool] $returnStatus = $true

    # Check if the task exists
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if ($task)
    {
        # Get task details
        $trigger = $task.Triggers | Select-Object -First 1
        if ($trigger.Repetition.Interval -ne $RepInterval)
        {
            $returnStatus = $false
        }
        if ($trigger.Repetition.Duration -ne $RepDuration)
        {
            $returnStatus = $false
        }
    }
    else
    {
        $returnStatus = $false
    }
    
    return $returnStatus
}

if (Test-ScheduledTaskDetails -TaskName $S_TaskName -TaskPath $S_TaskPath -RepInterval $S_RepInterval -RepDuration $S_RepDuration)
{
    Write-Output "$S_TaskName found in the system"
    exit 0
}
else
{
    Write-Output "$S_TaskName NOT found in the system"
    exit 1
}
