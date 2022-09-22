# PLEASE CHANGE SETTINGS BELOW
[String] $VPNConnectionName = ""        # Ex: "Contoso VPN (Managed)"
[String] $ServerAddress = ""            # Ex: "vpn.contoso.com"
[String] $L2tpPskSecret = ""            # Encrypted Secret
[String] $DnsSuffix = ""                # Ex: "contoso.local"
[String] $L2tpPsk = ""                  # Leave this blank


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

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false

# Decrypting the Password
try
{
    $SecurePwd = $L2tpPskSecret | ConvertTo-SecureString
    $Marshal = [System.Runtime.InteropServices.Marshal]
    $Bstr = $Marshal::SecureStringToBSTR($SecurePwd)
    $L2tpPsk = $Marshal::PtrToStringAuto($Bstr)
}
catch
{
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}


If (!(Get-VpnConnection -Name $VPNConnectionName -ErrorAction SilentlyContinue -AllUserConnection))
{
    try
    {
        Add-VpnConnection -Name $VPNConnectionName -ServerAddress $ServerAddress `
            -TunnelType "L2TP" -EncryptionLevel Required -AuthenticationMethod MSChapv2 `
            -PassThru -L2tpPsk $L2tpPsk -Force -Confirm:$false `
            -RememberCredential $true -AllUserConnection -DnsSuffix $DnsSuffix

        If (  (Get-VpnConnection -Name $VPNConnectionName -AllUserConnection).SplitTunneling   )
        {
            Set-VpnConnection -Name $VPNConnectionName -SplitTunneling $false -AllUserConnection
        }
    }
    Catch
    {
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }    
}
else
{
    Set-VpnConnection -Name $VPNConnectionName -ServerAddress $ServerAddress `
    -TunnelType "L2TP" -EncryptionLevel Required -AuthenticationMethod MSChapv2 `
    -SplitTunneling $false -PassThru -L2tpPsk $L2tpPsk -Force -Confirm:$false `
    -RememberCredential $true -AllUserConnection -DnsSuffix $DnsSuffix
}


Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"