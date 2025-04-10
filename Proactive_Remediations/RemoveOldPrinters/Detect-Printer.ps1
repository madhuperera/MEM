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
    Write-Output "Printers found: $($PrintersFoundToBeRemoved -join ', ')"
    exit 1
}
else
{
    Write-Output "No printers found."
    exit 0
}
