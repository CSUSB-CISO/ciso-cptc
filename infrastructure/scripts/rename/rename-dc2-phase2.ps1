<#
  Run this ON dc2 AFTER rebooting from rename-dc2-phase1.ps1, logged in as
  thelarpers\Administrator. Phase 2 of 2 -- removes the old alias name.

  Follow with dcdiag /v and repadmin /replsummary (check BOTH directions,
  dc1<->dc2) to confirm the domain is fully healthy with both DCs renamed.
#>

$ErrorActionPreference = 'Stop'
$newFqdn = 'dc2.thelarpers.local'
$oldFqdn = 'WIN-9BC7MIABOGR.thelarpers.local'

Write-Host "=== dc2 rename -- Phase 2 (remove old name) ===" -ForegroundColor Cyan

$current = (hostname)
if ($current -ine 'dc2') {
    Write-Warning "Current hostname is '$current', expected 'dc2'. The phase1 reboot may not have completed, or this isn't dc2. Aborting."
    exit 1
}

Write-Host "Current hostname confirmed as dc2. Removing old name alias..." -ForegroundColor Yellow
netdom computername $newFqdn /remove:$oldFqdn
if ($LASTEXITCODE -ne 0) { throw "netdom /remove failed with exit code $LASTEXITCODE" }

Write-Host ""
Write-Host "Done. Verifying..." -ForegroundColor Green
netdom query dc
repadmin /replsummary
Write-Host ""
Write-Host "Both DCs should now show as dc1 / dc2 above, with 0 replication failures." -ForegroundColor Cyan
