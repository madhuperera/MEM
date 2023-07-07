[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

# Account Details
[String] $SAccountName = "LocalAccountName" # Please change
[String] $SAccountFullName = "LAPS Managed Local Admin" # Please change
[String] $SAccountDesc = "LAPS Managed Local Administrator Account" # Please change

# Password Requirements and Details
[int] $SAccountPassLength = 14



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
        [int] $F_MaxCharLength,
        [String] $F_AllowedChars
    )

    [String] $F_AllowedPassLetters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    [String] $F_AllowedPassNumbers = "0123456789"
    [String] $F_AllowedPassAlphaN = "!@#$%^&*()_+=-"
    [String] $F_RandomPassword = ""
    $F_RandomObjLetters = New-Object -TypeName System.Random -ErrorAction SilentlyContinue
    $F_RandomObjNumbers = New-Object -TypeName System.Random -ErrorAction SilentlyContinue
    $F_RandomObjAlphaN = New-Object -TypeName System.Random -ErrorAction SilentlyContinue

    if ($F_MaxCharLength%3 -gt 0)
    {
        for ($i = 0; $i -lt $F_MaxCharLength%3; $i++)
        {
            $IndexL = $F_RandomObjLetters.Next(0, $F_AllowedPassLetters.Length)
            $F_RandomPassword += $F_AllowedPassLetters[$IndexL]
        }
    }

    for ($i = 0 ; $i -lt [Math]::Floor($F_MaxCharLength/3); $i++)
    {
        $IndexL = $F_RandomObjLetters.Next(0, $F_AllowedPassLetters.Length)
        $IndexN = $F_RandomObjNumbers.Next(0, $F_AllowedPassNumbers.Length)
        $IndexA = $F_RandomObjAlphaN.Next(0, $F_AllowedPassAlphaN.Length)
        $F_RandomPassword += $F_AllowedPassLetters[$IndexL]
        $F_RandomPassword += $F_AllowedPassNumbers[$IndexN]
        $F_RandomPassword += $F_AllowedPassAlphaN[$IndexA]
    }

    
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
