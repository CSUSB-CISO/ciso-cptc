<#
  Fallback / standalone version -- run directly ON sql1's own console if
  you'd rather not use rename-orchestrator-from-dc1.ps1.

  sql1 is standalone (not domain-joined -- only mssql_server/business_data
  roles apply to it in site.yml, no domain_join). Plain local Administrator
  rights are sufficient to rename it.
#>

$ErrorActionPreference = 'Stop'
$newName = 'sql1'

$current = (hostname)
if ($current -ieq $newName) {
    Write-Host "Already named $newName -- nothing to do." -ForegroundColor Yellow
    exit 0
}

Write-Host "Renaming $current -> $newName and restarting..." -ForegroundColor Yellow
Rename-Computer -NewName $newName -Force -Restart
