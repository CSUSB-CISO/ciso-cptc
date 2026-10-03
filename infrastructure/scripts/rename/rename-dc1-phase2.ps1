<#
  Run this ON dc1 AFTER rebooting from rename-dc1-phase1.ps1, logged in as
  thelarpers\Administrator. Phase 2 of 2 -- removes the old alias name,
  completing the rename.

  Confirms the new hostname is live, then runs:
    netdom computername dc1.thelarpers.local /remove:WIN-TD79R6IO8IK.thelarpers.local

  Follow with dcdiag /v and repadmin /replsummary to confirm dc1 is still
  healthy before touching dc2.
#>

$ErrorActionPreference = 'Stop'
$newFqdn = 'dc1.thelarpers.local'
$oldFqdn = 'WIN-TD79R6IO8IK.thelarpers.local'

Write-Host "=== dc1 rename -- Phase 2 (remove old name) ===" -ForegroundColor Cyan

$current = (hostname)
if ($current -ine 'dc1') {
    Write-Warning "Current hostname is '$current', expected 'dc1'. The phase1 reboot may not have completed, or this isn't dc1. Aborting."
    exit 1
}

Write-Host "Current hostname confirmed as dc1. Removing old name alias..." -ForegroundColor Yellow
netdom computername $newFqdn /remove:$oldFqdn
if ($LASTEXITCODE -ne 0) { throw "netdom /remove failed with exit code $LASTEXITCODE" }

Write-Host ""
Write-Host "Done. Verifying..." -ForegroundColor Green
netdom query dc
Write-Host ""
Write-Host "Run 'dcdiag /v' and 'repadmin /replsummary' next to confirm dc1 is still healthy" -ForegroundColor Cyan
Write-Host "before starting dc2's rename (rename-dc2-phase1.ps1)." -ForegroundColor Cyan
