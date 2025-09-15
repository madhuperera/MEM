if (-not (Get-Process -Name "WingetUI" -ErrorAction SilentlyContinue)) 
{
    Write-Output "WingetUI not running, starting in daemon mode..."
    Start-Process -FilePath "C:\Program Files\UniGetUI\WingetUI.exe" -ArgumentList "--daemon" -WindowStyle Hidden
}
else 
{
    Write-Output "WingetUI is already running."
}

exit 0
