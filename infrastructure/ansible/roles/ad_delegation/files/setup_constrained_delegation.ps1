$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

# Adapted from CyberHawks cyber-range roles/ad_delegation/files/setup_constrained_delegation.ps1
# (98307cc), owner permission 2026-10-03 -- see ../../../UPSTREAM.md.
# CyberHawks delegates sql1$/sql2$ to a single DC's cifs SPN; this range has
# TWO domain controllers (dc1, dc2) per the finding map, so both computer
# accounts are allowed to delegate to BOTH DCs' cifs service.

$targetSpnsCsv = $env:CONSTRAINED_DELEGATION_TARGET_SPNS
if (-not $targetSpnsCsv) { throw "CONSTRAINED_DELEGATION_TARGET_SPNS environment variable not set" }
$targetSpns = $targetSpnsCsv -split ","

# sql1$: constrained delegation WITHOUT protocol transition.
$sql1 = Get-ADComputer sql1 -Properties "msDS-AllowedToDelegateTo", TrustedToAuthForDelegation
$missingSql1 = $targetSpns | Where-Object { $sql1."msDS-AllowedToDelegateTo" -notcontains $_ }
if ($missingSql1) {
    Set-ADComputer sql1 -Add @{ "msDS-AllowedToDelegateTo" = $missingSql1 }
    Write-Output "Set msDS-AllowedToDelegateTo += $($missingSql1 -join ', ') on sql1$"
} else {
    Write-Output "sql1$ already has msDS-AllowedToDelegateTo for all target SPNs"
}
if ($sql1.TrustedToAuthForDelegation) {
    # Should stay OFF for sql1 -- this is the "no protocol transition" variant.
    Set-ADAccountControl -Identity "sql1$" -TrustedToAuthForDelegation $false
    Write-Output "Cleared TrustedToAuthForDelegation on sql1$ (must stay off for this variant)"
}

# sql2$: constrained delegation WITH protocol transition (T2A4D).
$sql2 = Get-ADComputer sql2 -Properties "msDS-AllowedToDelegateTo", TrustedToAuthForDelegation
$missingSql2 = $targetSpns | Where-Object { $sql2."msDS-AllowedToDelegateTo" -notcontains $_ }
if ($missingSql2) {
    Set-ADComputer sql2 -Add @{ "msDS-AllowedToDelegateTo" = $missingSql2 }
    Write-Output "Set msDS-AllowedToDelegateTo += $($missingSql2 -join ', ') on sql2$"
} else {
    Write-Output "sql2$ already has msDS-AllowedToDelegateTo for all target SPNs"
}
if (-not $sql2.TrustedToAuthForDelegation) {
    Set-ADAccountControl -Identity "sql2$" -TrustedToAuthForDelegation $true
    Write-Output "Set TrustedToAuthForDelegation on sql2$ (T2A4D)"
} else {
    Write-Output "sql2$ already has TrustedToAuthForDelegation set"
}
