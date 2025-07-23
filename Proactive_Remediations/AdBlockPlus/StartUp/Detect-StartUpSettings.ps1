$regChecks = 
@(
    @{
        Path = 'HKLM:\Software\Policies\Google\Chrome\3rdparty\extensions\cfhdojbkjhnklbpkdaibdccddilifddb\policy'
        Name = 'suppress_first_run_page'
        Data = 1
    },
    @{
        Path = 'HKLM:\Software\Policies\Microsoft\Edge\3rdparty\extensions\gmgoamodcdcjnbaobigkjelfplakmdhh\policy'
        Name = 'suppress_first_run_page'
        Data = 1
    }
)

Function Get-KeyValueData
{
    param
    (
        [string]$F_Reg_Key_Path,
        [string]$F_Reg_Key_Value_Name,
        [string]$F_Reg_Key_Value_Data
    )

    $key = Get-Item -Path $F_Reg_Key_Path -ErrorAction SilentlyContinue
    if ($key -ne $null)
    {
        $value = $key.GetValue($F_Reg_Key_Value_Name)
        if ($value -eq $F_Reg_Key_Value_Data)
        {
            return $true
        }
    }
    return $false
}

$results = @()
foreach ($check in $regChecks) 
{
    $result = Get-KeyValueData -F_Reg_Key_Path $check.Path -F_Reg_Key_Value_Name $check.Name -F_Reg_Key_Value_Data $check.Data
    $results += [PSCustomObject]@{
        Path = $check.Path
        Name = $check.Name
        ExpectedData = $check.Data
        ExistsAndMatches = $result
    }
}

if ($results.ExistsAndMatches -contains $false) 
{
    Write-Output "Some registry keys are missing or do not match the expected values:"
    exit 1
} 
else 
{
    Write-Output "All registry keys are present and match the expected values."
    exit 0
}

