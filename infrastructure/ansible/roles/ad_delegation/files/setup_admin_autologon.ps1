$ErrorActionPreference = "Stop"

# Adapted from CyberHawks cyber-range roles/ad_delegation/files/setup_admin_autologon.ps1
# (98307cc), owner permission 2026-10-03 -- see ../../../UPSTREAM.md.
# Account identity/domain templated via env vars instead of hardcoded
# "admin"/"CYBERHAWKS".

$daSam = $env:DA_ACCOUNT_SAM
$daPassword = $env:DA_ACCOUNT_PASSWORD
$netbiosDomain = $env:NETBIOS_DOMAIN
if (-not $daSam) { throw "DA_ACCOUNT_SAM environment variable not set" }
if (-not $daPassword) { throw "DA_ACCOUNT_PASSWORD environment variable not set" }
if (-not $netbiosDomain) { throw "NETBIOS_DOMAIN environment variable not set" }

$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
New-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -PropertyType String -Value "1" -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -PropertyType String -Value $daSam -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -PropertyType String -Value $netbiosDomain -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -PropertyType String -Value $daPassword -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "AutoLogonCount" -PropertyType DWord -Value 999999 -Force | Out-Null

Write-Output "Configured autologon for $daSam on this host"
