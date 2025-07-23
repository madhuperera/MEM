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

Function Set-KeyValueData
{
    param
    (
        [string]$F_Reg_Key_Path,
        [string]$F_Reg_Key_Value_Name,
        [string]$F_Reg_Key_Value_Data,
        [string]$F_Reg_Key_Value_Type
    )
    if (!(Test-Path $F_Reg_Key_Path))
    {
        New-Item -Path $F_Reg_Key_Path -Force | Out-Null
    }
    New-ItemProperty -Path $F_Reg_Key_Path -Name $F_Reg_Key_Value_Name -Value $F_Reg_Key_Value_Data -PropertyType $F_Reg_Key_Value_Type -Force | Out-Null
}

$exitCode = 0

foreach ($reg in $regChecks)
{
    try 
    {
        Set-KeyValueData -F_Reg_Key_Path $reg.Path `
                         -F_Reg_Key_Value_Name $reg.Name `
                         -F_Reg_Key_Value_Data $reg.Data `
                         -F_Reg_Key_Value_Type 'DWord'
    }
    catch 
    {
        Write-Error "Failed to set registry key: $($reg.Path)\$($reg.Name) - $_"
        $exitCode = 1
    }
}

exit $exitCode
