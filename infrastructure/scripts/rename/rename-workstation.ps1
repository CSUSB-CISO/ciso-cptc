<#
  Fallback / standalone version -- run directly ON workstation's own console
  if you'd rather not use rename-orchestrator-from-dc1.ps1.

  workstation is domain-joined (domain_join role in site.yml) -- same
  domain-credential requirement as ca/web. Its local account is "coach"
  (OOBE rejected "administrator" as a local account name on this Win11
  box), but that's irrelevant here since we're renaming with a domain
  credential, not the local one. See rename-ca.ps1 for details.
#>

$ErrorActionPreference = 'Stop'
$newName = 'workstation'

$current = (hostname)
if ($current -ieq $newName) {
    Write-Host "Already named $newName -- nothing to do." -ForegroundColor Yellow
    exit 0
}

$domainCred = Get-Credential -Message "Domain Administrator (thelarpers\Administrator) -- required to rename a domain-joined computer"

Write-Host "Renaming $current -> $newName and restarting..." -ForegroundColor Yellow
Rename-Computer -NewName $newName -DomainCredential $domainCred -Force -Restart
