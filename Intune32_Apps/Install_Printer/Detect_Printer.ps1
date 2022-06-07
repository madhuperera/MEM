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
                    exit $ExitWithNoError
                }
                else
                {
                    # Wrong IP Address
                    exit $ExitWithError
                }
            }
            else
            {
                # Wrong Port
                exit $ExitWithError
            }
        }
        else
        {
            # Wrong Driver
            exit $ExitWithError
        }
    }
    else
    {
        # No Printer
        exit $ExitWithError
    }
}
catch
{
    exit $ExitWithError
}