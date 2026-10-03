<#
  Fallback / standalone version -- run directly ON sql2's own console if
  you'd rather not use rename-orchestrator-from-dc1.ps1.

  sql2 is standalone (not domain-joined) -- same as sql1. Plain local
  Administrator rights are sufficient to rename it.
#>

$ErrorActionPreference = 'Stop'
$newName = 'sql2'

$current = (hostname)
if ($current -ieq $newName) {
    Write-Host "Already named $newName -- nothing to do." -ForegroundColor Yellow
    exit 0
}

Write-Host "Renaming $current -> $newName and restarting..." -ForegroundColor Yellow
Rename-Computer -NewName $newName -Force -Restart
