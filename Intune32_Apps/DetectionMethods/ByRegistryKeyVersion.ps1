[string]$S_Reg_Key_Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Logitech Unifying\" # Change the path
[string]$S_Reg_Key_Value_Name = "DisplayVersion" # Change Value Name
[string]$S_Reg_Key_Value_Data = "2.52.33" # Change Value Data

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

function Update-OutputOnExit
{
    param
    (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Output "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode)
    {
        exit 1
    }
    else
    {
        exit 0
    }
}

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
        if ($value -ge $F_Reg_Key_Value_Data)
        {
            return $true
        }
    }
    return $false
}



if (Get-KeyValueData -F_Reg_Key_Path $S_Reg_Key_Path -F_Reg_Key_Value_Name $S_Reg_Key_Value_Name -F_Reg_Key_Value_Data $S_Reg_Key_Value_Data)
{
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
else
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}
