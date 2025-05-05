param
(
    [string]$ClientName = "Sonitlo", # This will be used for the image name, avoid using spaces
    [string]$S_Reg_Key_Path = "HKLM:\SOFTWARE\$ClientName\IntuneConfigs\Lockscreen\",
    [string]$S_Reg_Key_ValueName = "CurrentLockscreen",
    [string]$DestinationFilePath = "C:\Windows\Web\Screen\$($ClientName)_Lockscreen.png"
)

Function Remove-KeyValueName
{
    param
    (
        [string]$F_Reg_Key_Path,
        [string]$F_Reg_Key_Value_Name
    )
    if (Test-Path $F_Reg_Key_Path)
    {
        Remove-ItemProperty -Path $F_Reg_Key_Path -Name $F_Reg_Key_Value_Name
    }
}

function main
{
    try
    {
        Remove-KeyValueName -F_Reg_Key_Path $S_Reg_Key_Path -F_Reg_Key_Value_Name $S_Reg_Key_ValueName
        Write-Output "Registry key $S_Reg_Key_ValueName removed successfully."

        if (Test-Path $DestinationFilePath)
        {
            Remove-Item -Path $DestinationFilePath -Force
            Write-Output "File $DestinationFilePath removed successfully."
        }
        else
        {
            Write-Output "File $DestinationFilePath does not exist."
        }
        exit 0
    }
    catch
    {
        write-output "Error: $_"
        exit 1
    }
}

main


