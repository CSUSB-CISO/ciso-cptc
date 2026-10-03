<#
  Run this ON dc2 (current name WIN-9BC7MIABOGR), logged in as
  thelarpers\Administrator, elevated PowerShell. Phase 1 of 2.

  Same netdom procedure as dc1 -- see rename-dc1-phase1.ps1 for the
  rationale. Only run this AFTER dc1 has completed its own rename
  end-to-end (phase1 -> reboot -> phase2 -> verified healthy). Don't
  rename both DCs at once.
#>

$ErrorActionPreference = 'Stop'
$oldFqdn = 'WIN-9BC7MIABOGR.thelarpers.local'
$newFqdn = 'dc2.thelarpers.local'

Write-Host "=== dc2 rename -- Phase 1 (add + makeprimary + reboot) ===" -ForegroundColor Cyan
Write-Host "Current: $oldFqdn  ->  New: $newFqdn"
Write-Host ""

$current = (hostname)
if ($current -ieq 'dc2') {
    Write-Host "Already named dc2 -- nothing to do. If you're re-running phase2, use that script instead." -ForegroundColor Yellow
    exit 0
}

Write-Host "Step 1/3: netdom computername /add..." -ForegroundColor Yellow
netdom computername $oldFqdn /add:$newFqdn
if ($LASTEXITCODE -ne 0) { throw "netdom /add failed with exit code $LASTEXITCODE" }

Write-Host "Waiting 30s for DNS/AD to register the new name..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "Step 2/3: netdom computername /makeprimary..." -ForegroundColor Yellow
netdom computername $oldFqdn /makeprimary:$newFqdn
if ($LASTEXITCODE -ne 0) { throw "netdom /makeprimary failed with exit code $LASTEXITCODE" }

Write-Host "Step 3/3: restarting to apply the primary name change..." -ForegroundColor Yellow
Write-Host "After reboot, log in as thelarpers\Administrator and run rename-dc2-phase2.ps1." -ForegroundColor Cyan
Start-Sleep -Seconds 5
Restart-Computer -Force
