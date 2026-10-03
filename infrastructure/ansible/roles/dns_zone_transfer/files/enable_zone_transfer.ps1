# Adapted from CyberHawks `cyber-range` roles/dns_zone_transfer/files/
# enable_zone_transfer.ps1 (98307cc), owner permission 2026-10-03 — see
# ../../../UPSTREAM.md. Change: zone name templated via env var instead of
# being hardcoded to cyberhawks.lab.
$ErrorActionPreference = "Stop"
Import-Module DnsServer

$zoneName = $env:ZONE_NAME
if (-not $zoneName) { throw "ZONE_NAME environment variable not set" }

$zone = Get-DnsServerZone -Name $zoneName

if ($zone.SecureSecondaries -ne "TransferAnyServer") {
    Set-DnsServerPrimaryZone -Name $zoneName -SecureSecondaries "TransferAnyServer"
    Write-Output "Enabled unrestricted zone transfer (AXFR) on $zoneName"
} else {
    Write-Output "Zone transfer already unrestricted on $zoneName"
}

Write-Output "DONE"
