$ApprovedListOfAdmins = 
@(
    "Admin1",
    "Admin2"
)


try 
{
    $LocalAdministrators = Get-LocalGroupMember -Group "Administrators" | Where-Object {$_.PrincipalSource -eq "Local"}
} 
catch 
{
    Write-Error "Failed to get local administrators: $_"
    exit 1
}

$UnapprovedAdmins = $LocalAdministrators | Where-Object {
    $LocalUser = $_.Name -split '\\' | Select-Object -Last 1
    $ApprovedListOfAdmins -notcontains $LocalUser
}

$EnabledUnapprovedAdmins = @()

foreach ($Admin in $UnapprovedAdmins)
{
    $LocalUserName = ($Admin.Name -split '\\')[1]
    
    try 
    {
        $User = Get-LocalUser -Name $LocalUserName -ErrorAction Stop
        
        if ($User.Enabled)
        {
            $EnabledUnapprovedAdmins += $Admin
        }
        else 
        {
            Write-Output "Skipping disabled account: $LocalUserName"
        }
    }
    catch 
    {
        Write-Warning "Could not retrieve user"
    }
}

if ($EnabledUnapprovedAdmins)
{
    $EnabledUnapprovedAdmins | ForEach-Object {
        $LocalUserName = ($_.Name -split '\\')[1]
        Write-Output "Unapproved local administrator found: $LocalUserName"
    }
    exit 1
}
else 
{
    Write-Output "No unapproved local administrators found."
    exit 0
}