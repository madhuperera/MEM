if (Get-Process -Name "WingetUI" -ErrorAction SilentlyContinue) 
{
    Write-Output "WingetUI is running."
    exit 0
}
else 
{
    Write-Output "WingetUI is NOT running."
    exit 1
}
