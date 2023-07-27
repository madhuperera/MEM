param
(
    [String] $SAccountName = "LocalAccountName",
    [String] $SAccountFullName = "LAPS Managed Local Admin",
    [String] $SAccountDesc = "LAPS Managed Local Administrator Account",
    [int] $SAccountPassLength = 14
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

$UserAccount = Get-LocalUser $SAccountName -ErrorAction SilentlyContinue
if ($UserAccount)
{
    if (Get-LocalGroupMember -Group "Administrators" -Member "*\$SAccountName" -ErrorAction SilentlyContinue)
    {
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
    else
    {
        Add-LocalGroupMember -Group "Administrators" -Member $SAccountName -ErrorAction SilentlyContinue
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
}
else
{
    try
    {
        New-LocalUser -Name $SAccountName -Description $SAccountDesc -FullName $SAccountFullName `
        -Password (ConvertTo-SecureString -String (Get-RandomPassword -F_MaxCharLength $SAccountPassLength) -Force -AsPlainText -ErrorAction SilentlyContinue)
    
        Add-LocalGroupMember -Group "Administrators" -Member $SAccountName -ErrorAction SilentlyContinue
    }
    catch
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
}
