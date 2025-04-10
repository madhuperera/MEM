$PrintersToRemove = 
@(
    "*FindMe-BW*",
    "*FindMe-Colour*"
)

[bool] $PrinterFound = $false

# List of printers found
$PrintersFoundToBeRemoved = @()

foreach ($Printer in $PrintersToRemove)
{
    $CurrentPrinter = ""
    $CurrentPrinter = Get-Printer -Name $Printer -ErrorAction SilentlyContinue
    if ($CurrentPrinter)
    {
        $PrinterFound = $true
        $PrintersFoundToBeRemoved += $($CurrentPrinter.Name)
    }
    else
    {
        continue
    }
}

if ($PrinterFound -eq $true)
{
    try
    {
        foreach ($Printer in $PrintersFoundToBeRemoved)
        {
            Write-Output "Removing printer: $Printer"
            Remove-Printer -Name $Printer -ErrorAction Stop -Confirm:$false
        }
        exit 0
    }
    catch
    {
        Write-Output "Error removing printer: $_"
        exit 1
    }
}
else
{
    Write-Output "No printers found."
    exit 0
}

