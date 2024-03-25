param
(
    [String] $S_CompanyName = "Sonitlo",
    [String] $S_ScriptName = "MSWORDTEMPLATE",
    [String] $S_FilePath = "$ENV:APPDATA\Microsoft\Templates\Normal.dotm",
    [String] $S_Algorithm = "SHA256",
    [String] $S_ExpectedHash = "02DD3007E8713674E52C1E2C18459B02BE39BAEC9B30BC989CB8440051F9C1CF"
)
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

function Start-ScriptLogs
{
    param
    (
        [String] $F_CompanyName,
        [String] $F_ScriptName,
        [String] $F_LogDirectory = "C:\ProgramData\$($F_CompanyName)IntuneManaged\Logs\$F_ScriptName",
        [String] $F_LogName = "Logs.txt",
        [String] $F_LogPath = "$F_LogDirectory\$F_LogName"
    )
    
    Start-Transcript -Path $F_LogPath -Force -Append
}

Start-ScriptLogs -F_CompanyName $S_CompanyName -F_ScriptName $S_ScriptName

function Test-FileHash
{
    param
    (
        [string] $F_FilePath,
        [ValidateSet("SHA1", "SHA256", "SHA384", "SHA512", "MD5", "MACTripleDES", "RIPEMD160")]
        [String] $F_Algorithm,
        [String] $F_ExpectedHash
    )
    try
    {
        
        $FileHash = (Get-FileHash -Path $F_FilePath -Algorithm $F_Algorithm -ErrorAction Stop).Hash
        return $FileHash -eq $F_ExpectedHash
    }
    catch
    {
        if ($_.Exception.Message -match "because it is being used by another process")
        {
            Write-Host "The file could not be accessed because it is being used by another process."
            Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
        }
        else
        {
            Write-Error "An error occurred while trying to get the hash of the file: $($_.Exception.Message)"
            Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
        }
    }
}

try
{
    $S_FilePath
    if (!(Test-FileHash -F_FilePath $S_FilePath -F_Algorithm $S_Algorithm -F_ExpectedHash $S_ExpectedHash))
    {
        Copy-Item -Path -Destination -Force -Confirm:$false -ErrorAction Stop
        Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
    }
}
catch
{
    Write-Error "An error occurred while trying to get the hash of the file: $($_.Exception.Message)"
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}


Stop-Transcript