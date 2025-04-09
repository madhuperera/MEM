param
(
    [string]$ClientName = "Sonitlo",
    [string]$S_Reg_Key_Path = "HKLM:\SOFTWARE\$ClientName\IntuneConfigs\Lockscreen\",
    [string]$S_Reg_Key_ValueName = "CurrentLockscreen",
    [string]$S_Reg_Key_ValueData = "", # This will be set to the blob name after download
    [string]$S_Reg_Key_ValueType = "String",
    [string]$ContainerUrl = "https://<your-storage-account>.blob.core.windows.net/<container>/<Folder>?<SAS-token>",
    [string]$DestinationFilePath = "C:\Windows\Web\Screen\VO_Lockscreen.png"
)
function Get-BlobItems
{
    param 
    (
        $URL
    )
    
    $uri = $URL.split('?')[0]
    $sas = $URL.split('?')[1]
    
    $newurl = $uri + "?restype=container&comp=list&" + $sas 
    
    #Invoke REST API
    $body = Invoke-RestMethod -uri $newurl

    #cleanup answer and convert body to XML
    $xml = [xml]$body.Substring($body.IndexOf('<'))

    #use only the relative Path from the returned objects
    $files = $xml.ChildNodes.Blobs.Blob.Name

    #regenerate the download URL incliding the SAS token
    $files | ForEach-Object { $uri + "/" + $_ + "?" + $sas }    
}

Function Set-KeyValueData
{
    param
    (
        [string]$F_Reg_Key_Path,
        [string]$F_Reg_Key_Value_Name,
        [string]$F_Reg_Key_Value_Data,
        [string]$F_Reg_Key_Value_Type
    )
    if (!(Test-Path $F_Reg_Key_Path))
    {
        New-Item -Path $F_Reg_Key_Path -Force | Out-Null
    }
    New-ItemProperty -Path $F_Reg_Key_Path -Name $F_Reg_Key_Value_Name -Value $F_Reg_Key_Value_Data -PropertyType $F_Reg_Key_Value_Type -Force | Out-Null
}

function main
{
    $AllBlobItems = Get-BlobItems -URL $ContainerUrl

    # Retrieve the blob names from the $AllBlobItems object
    $BlobNames = foreach ($Blob in $AllBlobItems)
    {
        ($Blob -split '\?')[0] -replace '.*/', ''
    }

    if ($AllBlobItems.Count -ne 1) {
        Write-Error "There is more than one file to copy. Exiting script."
        exit 1
    }

    $S_Reg_Key_ValueData = $BlobNames

    try
    {
        # Download the blob to the destination folder
       
        Invoke-WebRequest -Uri $AllBlobItems -OutFile $DestinationFilePath
        Write-Output "File downloaded successfully to $DestinationFilePath"
        
        Set-KeyValueData -F_Reg_Key_Path $S_Reg_Key_Path -F_Reg_Key_Value_Name $S_Reg_Key_ValueName -F_Reg_Key_Value_Data $S_Reg_Key_ValueData -F_Reg_Key_Value_Type $S_Reg_Key_ValueType
        Write-Output "Registry key value set: $($S_Reg_Key_Path)$($S_Reg_Key_ValueName) = $S_Reg_Key_ValueData"

        exit 0
    }
    catch
    {
        Write-Output "Error downloading file: $_"
        exit 1
    }
}

main


