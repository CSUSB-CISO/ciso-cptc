<#
  Fallback / standalone version -- run directly ON ca's own console if you'd
  rather not use rename-orchestrator-from-dc1.ps1. Not needed if the
  orchestrator already handled this host successfully.

  ca is domain-joined (adcs_ca role via domain_join in site.yml), so renaming
  it requires a credential with rights over its AD computer object -- the
  local Administrator alone is not enough (this is almost certainly why a
  live Rename-Computer attempt failed with "user name or password is
  incorrect" earlier this session). Prompts for the domain Administrator
  credential interactively -- nothing is embedded in this file.
#>

$ErrorActionPreference = 'Stop'
$newName = 'ca'

$current = (hostname)
if ($current -ieq $newName) {
    Write-Host "Already named $newName -- nothing to do." -ForegroundColor Yellow
    exit 0
}

$domainCred = Get-Credential -Message "Domain Administrator (thelarpers\Administrator) -- required to rename a domain-joined computer"

Write-Host "Renaming $current -> $newName and restarting..." -ForegroundColor Yellow
Rename-Computer -NewName $newName -DomainCredential $domainCred -Force -Restart
