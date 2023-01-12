$LogPath = "$env:ProgramData\Azure Intune\Repository\FontsLogs.txt"
Start-Transcript -Path $LogPath

$SourceFontFolder = "$PSScriptRoot\Fonts"
$WindowsFontFolder = "C:\Windows\Fonts"
$WindowsFontRegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

# Creating a Shell Object to access the folders and files
try
{
    $objShell = New-Object -ComObject Shell.Application
}
catch 
{
    Write-Output "Error creating Com Object"    
    Write-Output $_.Exception
}


if (!(Test-Path $SourceFontFolder -PathType Container)) {
    Write-Output "Source Font folder is not located at $SourceFontFolder"
}
else
{
    Write-Output "Source Font folder is found"
    $objFolder = $objShell.namespace($SourceFontFolder)
    Write-Output "Going through each font found"
    foreach ($font in $objFolder.items())
    {
        Write-Output "----------------- $($font.Name) --------------------"
        $FontType = $($objFolder.getDetailsOf($Font, 2))

        if (($FontType -eq "OpenType font file") -or ($FontType -eq "TrueType font file"))
        {
            $FontName = $($objFolder.getDetailsOf($Font, 21))
            $FontTypeName = "(" + ($FontType -split " ")[0] + ")"
            $RegKeyItemName = $FontName + " " + $FontTypeName
            $FontFullName = (Get-Item -Path $font.Path).Name
            $FontDestPath = $WindowsFontFolder + "\$FontFullName"
            
            try
            {
                if (!(Test-Path -Path $FontDestPath -PathType Leaf))
                {
                    Write-Output "$FontDestPath not found"
                    Copy-Item -Path $font.path -Destination $WindowsFontFolder -Force
                    Write-Output "Successfully copied to $FontDestPath"
                }
                else
                {
                    Write-Output "$FontDestPath already found....."    
                }
                
                New-ItemProperty -Path $WindowsFontRegistryKey -Name $RegKeyItemName -PropertyType String -Value $FontFullName -Force
            }
            catch
            {
                Write-Output "Trouble creating the font: $($font.Name)"
                Write-Output $_.Exception
            }
            
        }
        else {
            Write-Output "Unknown Font Type"
        }
    }
}


Write-Output "All Fonts have been successfully installed and updated"
Stop-Transcript
