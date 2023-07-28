param
(
    [String] $SAccountName = "LocalAccountName",
    [String] $SAccountFullName = "LAPS Managed Local Admin",
    [String] $SAccountDesc = "LAPS Managed Local Administrator Account",
    [int] $SAccountPassLength = 14,
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "LAPS"
)


If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}


[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

function Start-ScriptLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_LogDirectory = "C:\ProgramData\$($CompanyName)IntuneManaged\Logs\$ScriptName",
        [String] $F_LogName = "Logs.txt",
        [String] $F_LogPath = "$LogDirectory\$LogName"
    )
    
    Start-Transcript -Path $F_LogPath -Force -Append
}
Start-ScriptLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName

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
        Stop-Transcript
        exit 1
    }
    else
    {
        Stop-Transcript
        exit 0
    }
}

function Get-RandomPassword
{
    param
    (
        [int] $F_MaxCharLength
    )

    [String] $F_RandomPassword = ""

    # Ensure at least one third of the length for each type of character
    $MinNumNumbers = [math]::Ceiling($F_MaxCharLength / 3)
    $MinNumUpperCase = [math]::Ceiling($F_MaxCharLength / 3)
    $MinNumLowerCase = $F_MaxCharLength - $MinNumNumbers - $MinNumUpperCase

    # Initialize arrays to store characters for each category
    $RandomNumbers = @()
    $RandomUpperCase = @()
    $RandomLowerCase = @()

    for ($i = 1; $i -le $MinNumNumbers; $i++)
    {
        $RandomNumbers += Get-Random -Minimum 0 -Maximum 9
    }
    
    # Generate random uppercase letters
    for ($i = 1; $i -le $MinNumUpperCase; $i++)
    {
        $RandomUpperCase += [char](Get-Random -Minimum 65 -Maximum 91)
    }
    
    # Generate random lowercase letters
    for ($i = 1; $i -le $MinNumLowerCase; $i++)
    {
        $RandomLowerCase += [char](Get-Random -Minimum 97 -Maximum 123)
    }

    $CombinedChars = $RandomNumbers + $RandomUpperCase + $RandomLowerCase | Get-Random -Count $F_MaxCharLength
    $F_RandomPassword = $CombinedChars -join ''

    return $F_RandomPassword
}

function Test-LAPSUserGroup
{
    param 
    (
        [string] $F_UserName,
        [String] $F_GroupName = "Administrators"
    )

    try
    {
        # Try the Modern PS Cmdlet
        $LMembers = Get-LocalGroupMember -Group $F_GroupName -ErrorAction Stop | Where-Object {$_.Name -like "*\$F_UserName" } 
    }
    catch
    {
        # Reverting to Dos Command to get the Local Group Members
        $LMembers = net localgroup $F_GroupName
        $LMembers = $LMembers | Select-Object -Skip 6
        $LMembers = $LMembers | Where-Object {$_ -like "*$F_UserName*"}
    }

    if ($LMembers)
    {
        return $true
    }
    else 
    {
        return $false
    }

}

function Add-LAPSUserToGroup
{
    param 
    (
        [string] $F_UserName,
        [string] $F_GroupName = "Administrators"
    )

    try
    {
        # Try the Modern PS Cmdlet
        Add-LocalGroupMember -Group $F_GroupName -Member $F_UserName -ErrorAction Stop   
    }
    catch
    {
        # Reverting to Dos Command
        net locagroup $F_GroupName $F_UserName /add
    }
}

$UserAccount = Get-LocalUser $SAccountName -ErrorAction SilentlyContinue
if ($UserAccount)
{
    if (Test-LAPSUserGroup -F_UserName $UserAccount)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    else
    {
        Add-LAPSUserToGroup -F_GroupName "Administrators" -F_UserName $SAccountName

        if (Test-LAPSUserGroup -F_UserName $UserAccount)
        {
            Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
        }
        else
        {
            Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "ERROR"
        }        
    }
}
else
{
    [String] $RandomPassword = Get-RandomPassword -F_MaxCharLength $SAccountPassLength

    try
    {
        # Try Modern PS Cmdlet
        New-LocalUser -Name $SAccountName -Description $SAccountDesc -FullName $SAccountFullName `
        -Password (ConvertTo-SecureString -String $RandomPassword -Force -AsPlainText -ErrorAction Stop)
    }
    catch
    {
        # Revertto using old cmdlet
        net user $SAccountName $RandomPassword /add
    }
    Add-LAPSUserToGroup -F_UserName $SAccountName -F_GroupName "Administrators"

    if (Test-LAPSUserGroup -F_UserName $UserAccount)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    else
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "ERROR"
    }
}
