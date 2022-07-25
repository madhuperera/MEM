# ------------ MEM VARIABLES ----------------
[CmdletBinding()]
param
(
    [Parameter()]
    [String] $PrinterPortIPAddress = "PLEASE_CHANGE_ME", # EX: 192.168.100.100
    [Parameter()]
    [String] $PrinterPortName = "PLEASE_CHANGE_ME", # EX: 192.168.100.100
    [Parameter()]
    [String] $PrinterName = "PLEASE_CHANGE_ME", # EX: Canon Head Office
    [Parameter()]
    [String] $PrinterDriverModelName = "PLEASE_CHANGE_ME" # EX: Canon Generic Plus PCL6
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


try
{
    $Printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($Printer)
    {
        if ($Printer.DriverName -eq $PrinterDriverModelName)
        {
            $PrinterPort = Get-PrinterPort -Name $($Printer.PortName) -ErrorAction SilentlyContinue
            if ($PrinterPort)
            {
                if ($PrinterPort.PrinterHostAddress -eq $PrinterPortIPAddress)
                {
                    # All checks pass
                    Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
                }
                else
                {
                    # Wrong IP Address
                    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
                }
            }
            else
            {
                # Wrong Port
                Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
            }
        }
        else
        {
            # Wrong Driver
            Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
        }
    }
    else
    {
        # No Printer
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}
catch
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}