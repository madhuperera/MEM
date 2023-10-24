# Kudos to https://github.com/andrew-s-taylor/public/blob/main/De-Bloat/RemoveBloat.ps1

write-host "Detecting McAfee"
$mcafeeinstalled = "false"
$InstalledSoftware = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
foreach ($obj in $InstalledSoftware)
{
    $name = $obj.GetValue('DisplayName')
    if ($name -like "*McAfee*")
    {
        $mcafeeinstalled = "true"
    }
}

$InstalledSoftware32 = Get-ChildItem "HKLM:\Software\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall"
foreach ($obj32 in $InstalledSoftware32)
{
    $name32 = $obj32.GetValue('DisplayName')
    if ($name32 -like "*McAfee*")
    {
        $mcafeeinstalled = "true"
    }
}

if ($mcafeeinstalled -eq "true")
{
    Write-Host "McAfee detected"
    #Remove McAfee bloat

    # Automate Removal and kill services
    start-process ".\mcafeeclean\Mccleanup.exe" -ArgumentList "-p StopServices,MFSY,PEF,MXD,CSP,Sustainability,MOCP,MFP,APPSTATS,Auth,EMproxy,FWdiver,HW,MAS,MAT,MBK,MCPR,McProxy,McSvcHost,VUL,MHN,MNA,MOBK,MPFP,MPFPCU,MPS,SHRED,MPSCU,MQC,MQCCU,MSAD,MSHR,MSK,MSKCU,MWL,NMC,RedirSvc,VS,REMEDIATION,MSC,YAP,TRUEKEY,LAM,PCB,Symlink,SafeConnect,MGS,WMIRemover,RESIDUE -v -s"
    write-host "McAfee Removal Tool has been run"
}