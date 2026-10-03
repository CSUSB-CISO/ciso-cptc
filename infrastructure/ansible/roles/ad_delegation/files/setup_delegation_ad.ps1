$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

# Adapted from CyberHawks cyber-range roles/ad_delegation/files/setup_delegation_ad.ps1
# (98307cc), owner permission 2026-10-03 -- see ../../../UPSTREAM.md.
# Templated for thelarpers.local instead of cyberhawks.lab; account identity
# and target computer come from env vars instead of being hardcoded.

$daSam = $env:DA_ACCOUNT_SAM
$daName = $env:DA_ACCOUNT_NAME
$daPassword = $env:DA_ACCOUNT_PASSWORD
$upnDomain = $env:UPN_DOMAIN
$delegationComputer = $env:UNCONSTRAINED_DELEGATION_COMPUTER
if (-not $daSam) { throw "DA_ACCOUNT_SAM environment variable not set" }
if (-not $daName) { throw "DA_ACCOUNT_NAME environment variable not set" }
if (-not $daPassword) { throw "DA_ACCOUNT_PASSWORD environment variable not set" }
if (-not $upnDomain) { throw "UPN_DOMAIN environment variable not set" }
if (-not $delegationComputer) { throw "UNCONSTRAINED_DELEGATION_COMPUTER environment variable not set" }

$nameParts = $daName.Split(" ")
$firstName = $nameParts[0]
$lastName = $nameParts[-1]

# Dedicated Domain Admin account whose session/TGT is the thing captured via
# $delegationComputer's Unconstrained Delegation below. Not a Stage 1/2
# starter account -- its password is never meant to be known/guessed, only
# reached via LSASS capture after a coercion-triggered logon.
if (-not (Get-ADUser -Filter "SamAccountName -eq '$daSam'" -ErrorAction SilentlyContinue)) {
    $securePw = ConvertTo-SecureString $daPassword -AsPlainText -Force
    New-ADUser -Name $daName -SamAccountName $daSam -UserPrincipalName "$daSam@$upnDomain" `
        -GivenName $firstName -Surname $lastName `
        -AccountPassword $securePw -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false
    Add-ADGroupMember -Identity "Domain Admins" -Members $daSam
    Write-Output "Created $daSam account and added to Domain Admins"
} else {
    Set-ADAccountPassword -Identity $daSam -NewPassword (ConvertTo-SecureString $daPassword -AsPlainText -Force) -Reset
    Set-ADUser -Identity $daSam -Enabled $true -PasswordNeverExpires $true
    if (-not (Get-ADGroupMember -Identity "Domain Admins" | Where-Object { $_.SamAccountName -eq $daSam })) {
        Add-ADGroupMember -Identity "Domain Admins" -Members $daSam
    }
    Write-Output "Converged existing $daSam account to documented state"
}

# Target computer account: Unconstrained Delegation.
$target = Get-ADComputer $delegationComputer -Properties TrustedForDelegation
if (-not $target.TrustedForDelegation) {
    Set-ADAccountControl -Identity "$delegationComputer$" -TrustedForDelegation $true
    Write-Output "Enabled Unconstrained Delegation on $delegationComputer$"
} else {
    Write-Output "Unconstrained Delegation already enabled on $delegationComputer$"
}
