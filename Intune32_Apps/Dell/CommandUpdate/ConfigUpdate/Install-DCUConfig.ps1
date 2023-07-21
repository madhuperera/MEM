If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}

[String] $SReg_Key_Parent_Path = "HKLM:\SOFTWARE\IntuneManagedApps"
[String] $SReg_Key_Name = "DellCommandConfig"
[String] $SReg_Key_Value_Name = "Version"
[String] $SReg_Key_Value_Data = "2023.07.21"
[ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "Qword")] $SReg_Key_Value_Type = "String"
[String] $CompanyName = "MEM" # Please change this
[String] $DCUCLIPath = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
# Configuration
[String] $ConfigDirectory = "C:\ProgramData\$($CompanyName)IntuneManaged\Configs\DellConfigUpdate"
[String] $ConfigName = "Settings.xml"
[String] $ConfigPath = "$ConfigDirectory\$ConfigName"
# Logging
[String] $LogDirectory = "C:\ProgramData\$($CompanyName)IntuneManaged\Logs\DellConfigUpdate"
[String] $LogName = "Logs.txt"
[String] $LogPath = "$LogDirectory\$LogName"
[String] $CustomLogName = "CustomLogs.txt"
[String] $CustomLogPath = "$LogDirectory\$CustomLogName"

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

Start-Transcript -Path $LogPath -Force -Append

function Update-RegistryKey {
    param
    (
        [String] $Reg_Key_Parent_Path,
        [String] $Reg_Key_Name,
        [String] $Reg_Key_Value_Name,
        [String] $Reg_Key_Value_Data,
        [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "Qword")] $Reg_Key_Value_Type
    )
    "$(Get-Date -Format "yyyy-MM-dd-HH:mm:ss__")$Reg_Key_Parent_Path\$Reg_Key_Name\$Reg_Key_Value_Name\$Reg_Key_Value_Data\$Reg_Key_Value_Type" | Out-File -FilePath $CustomLogPath -Append -Force -ErrorAction SilentlyContinue
    if (!(Test-Path -Path "$Reg_Key_Parent_Path\$Reg_Key_Name" -PathType Container)) {
        New-Item -Path $Reg_Key_Parent_Path -Name $Reg_Key_Name -ItemType Conatiner -Force -Verbose | Out-Null
    }

    if ($Reg_Key_Value_Data -and $Reg_Key_Value_Name) {
        try {
            New-ItemProperty -Path "$Reg_Key_Parent_Path\$Reg_Key_Name" -Name $Reg_Key_Value_Name -PropertyType $Reg_Key_Value_Type -Value $Reg_Key_Value_Data -Force -Verbose | Out-Null
        }
        catch {
            return $false
        }
        
    }
    return $true
}

function Update-OutputOnExit {
    param
    (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Host "STATUS=$F_Message" -ErrorAction SilentlyContinue

    if ($F_ExitCode) {
        Stop-Transcript
        exit 1
    }
    else {
        Stop-Transcript
        exit 0
    }
}

if (Test-Path -Path $DCUCLIPath -PathType Leaf -ErrorAction SilentlyContinue) {
    if (!(Test-Path -Path $ConfigDirectory -PathType Container -ErrorAction SilentlyContinue)) {
        New-Item -Path $ConfigDirectory -ItemType Directory -Force -ErrorAction SilentlyContinue
    }

    if (!(Test-Path -Path $ConfigPath -PathType Leaf -ErrorAction SilentlyContinue)) {
        Copy-Item -Path ".\$ConfigName" -Destination $ConfigDirectory -Force -ErrorAction SilentlyContinue
    }
    
    & $DCUCLIPath /configure -importSettings="$ConfigPath"
    if ($LASTEXITCODE -eq 0) {
        "$(Get-Date -Format "yyyy-MM-dd-HH:mm:ss__")$SReg_Key_Parent_Path\$SReg_Key_Name\$SReg_Key_Value_Name\$SReg_Key_Value_Data\$SReg_Key_Value_Type" | Out-File -FilePath $CustomLogPath -Append -Force -ErrorAction SilentlyContinue
        if (Update-RegistryKey -Reg_Key_Parent_Path $SReg_Key_Parent_Path -Reg_Key_Name $SReg_Key_Name -Reg_Key_Value_Name $SReg_Key_Value_Name -Reg_Key_Value_Data $SReg_Key_Value_Data -Reg_Key_Value_Type $SReg_Key_Value_Type) {
            Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
        }
        else {
            Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
        }
        
    }
    else {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}
else {
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}



