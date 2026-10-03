<#
  Fallback / standalone version -- run directly ON web's own console if you'd
  rather not use rename-orchestrator-from-dc1.ps1.

  web is domain-joined (iis_web role via domain_join in site.yml) -- same
  domain-credential requirement as ca. See rename-ca.ps1 for details.
#>

$ErrorActionPreference = 'Stop'
$newName = 'web'

$current = (hostname)
if ($current -ieq $newName) {
    Write-Host "Already named $newName -- nothing to do." -ForegroundColor Yellow
    exit 0
}

$domainCred = Get-Credential -Message "Domain Administrator (thelarpers\Administrator) -- required to rename a domain-joined computer"

Write-Host "Renaming $current -> $newName and restarting..." -ForegroundColor Yellow
Rename-Computer -NewName $newName -DomainCredential $domainCred -Force -Restart
