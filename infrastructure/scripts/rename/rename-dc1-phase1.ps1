<#
  Run this ON dc1 (current name WIN-TD79R6IO8IK), logged in as
  thelarpers\Administrator, elevated PowerShell. Phase 1 of 2.

  Rename-Computer is NOT supported on a live domain controller -- it does
  not correctly update the NTDS Settings object, SPNs, or DNS records.
  This uses the supported netdom procedure instead:
    1. Register the new name as an alias (/add)
    2. Wait briefly for it to register
    3. Promote it to the primary name (/makeprimary) -- takes effect on reboot
    4. Reboot

  After the reboot, log back in (now as thelarpers\Administrator on "dc1")
  and run rename-dc1-phase2.ps1 to remove the old name.

  Do NOT run this at the same time as dc2's rename -- the domain needs at
  least one DC up and healthy throughout. Finish dc1 end-to-end (phase1 ->
  reboot -> phase2 -> verify healthy) before starting dc2.
#>

$ErrorActionPreference = 'Stop'
$oldFqdn = 'WIN-TD79R6IO8IK.thelarpers.local'
$newFqdn = 'dc1.thelarpers.local'

Write-Host "=== dc1 rename -- Phase 1 (add + makeprimary + reboot) ===" -ForegroundColor Cyan
Write-Host "Current: $oldFqdn  ->  New: $newFqdn"
Write-Host ""

$current = (hostname)
if ($current -ieq 'dc1') {
    Write-Host "Already named dc1 -- nothing to do. If you're re-running phase2, use that script instead." -ForegroundColor Yellow
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
Write-Host "After reboot, log in as thelarpers\Administrator and run rename-dc1-phase2.ps1." -ForegroundColor Cyan
Start-Sleep -Seconds 5
Restart-Computer -Force
