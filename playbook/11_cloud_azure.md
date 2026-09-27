# 11 — Cloud, Azure / Entra ID & M365 (only if in scope)

**Goal:** if the scenario exposes cloud identity or resources (Entra ID / Azure AD, Azure subscriptions,
M365, or AWS/GCP), enumerate and demonstrate risk. **Most CPTC engagements are on-prem AD** — only
touch cloud tenants/subscriptions that are explicitly in the ROE. Cloud auth attempts are logged and
often billed to the client; be deliberate.

> **Scope check first.** Confirm in writing which tenant IDs, subscriptions, domains, and accounts are
> in scope. Never spray or token-abuse a tenant you weren't given. Revoke any tokens you mint when done.

## Unauthenticated / recon (identity is the perimeter)
```bash
# Does the org use Entra/M365? Which domains are federated vs managed?
python3 -c "import requests"   # (use your preferred tool below)
# o365 / Entra user + domain recon
o365spray --validate --domain <DOMAIN>
o365spray --enum --domain <DOMAIN> -U users.txt          # valid-user enumeration (no lockout on some)
AADInternals> Get-AADIntLoginInformation -Domain <DOMAIN> # tenant brand, DesktopSSO, federation
AADInternals> Invoke-AADIntReconAsOutsider -DomainName <DOMAIN>
# Cloud asset / subdomain surface
subfinder -d <DOMAIN>; amass enum -d <DOMAIN>            # look for *.azurewebsites.net, blob.core.windows.net, s3
# Public storage exposure
# Azure blobs: https://<account>.blob.core.windows.net/<container>?restype=container&comp=list
# AWS S3:      aws s3 ls s3://<bucket> --no-sign-request
```

## Password spray / initial access (respect lockout + Conditional Access)
```bash
# Low-and-slow spray against Entra sign-in (MFA/CA may block — that's a control finding)
o365spray --spray --domain <DOMAIN> -U users.txt -P '<PASS>'
MSOLSpray.ps1 -UserList users.txt -Password '<PASS>'
# Legacy auth endpoints sometimes bypass MFA — test if present (a finding either way)
```

## Authenticated enumeration (Entra ID / Azure)
```powershell
# AzureHound → BloodHound (cloud attack paths, same as on-prem workflow in 05)
AzureHound.exe -u '<USER>' -p '<PASS>' list --tenant <TENANT_ID> -o azurehound.json
# ROADtools — dump the whole directory
roadrecon auth -u '<USER>' -p '<PASS>'; roadrecon gather; roadrecon gui
# Az PowerShell / CLI once you hold a token
Connect-AzAccount ; Get-AzResource ; Get-AzRoleAssignment
az login ; az account list ; az resource list ; az role assignment list --all
# Microsoft Graph
Connect-MgGraph ; Get-MgUser -All ; Get-MgApplication -All ; Get-MgServicePrincipal -All
```

## Audit / config-review tooling (your CPEN-Azure kit)
```powershell
Invoke-AzAudit            # broad Azure posture audit
Invoke-EntraAudit         # Entra ID (Azure AD) audit
MicroBurst (Import-Module) # Get-AzureDomainInfo, Invoke-EnumerateAzureBlobs, Get-AzPasswords
Get-AzureADPSPermissions.ps1   # app/delegated permission grants (consent abuse)
Get-NSGs / Get-AzNetworkSecurityGroup  # exposed NSG rules
```

## Common privilege-escalation / abuse paths
- **Overprivileged roles**: Global Admin, Privileged Role Admin, or Owner/Contributor at subscription root.
- **App/service-principal abuse**: high API permissions (e.g. `RoleManagement.ReadWrite.Directory`),
  client secrets in code/pipelines, consent grant (illicit consent) → app acts as user.
- **Managed identity / VM RunCommand**: Contributor on a VM → run commands as the VM's managed identity →
  pull tokens from IMDS (`169.254.169.254`) → escalate in the subscription.
- **Automation Accounts / Runbooks / Key Vault**: readable secrets, stored RunAs creds.
- **Hybrid**: on-prem → cloud via **Azure AD Connect** sync account (`MSOL_*` — seen in your notes),
  PHS/PTA/seamless SSO abuse, or cloud → on-prem via Intune script push.
- **Storage**: public/SAS-exposed blobs & S3 buckets with sensitive data.

## AWS / GCP (if that's the scope instead)
```bash
# AWS
aws sts get-caller-identity            # who am I
pacu                                    # AWS exploitation framework (enum + privesc modules)
ScoutSuite aws                          # multi-cloud posture audit
enumerate-iam --access-key .. --secret-key ..
# GCP
gcloud auth list ; gcloud projects list
ScoutSuite gcp
```

## Evidence to capture
- The identity/role that granted access and **the misconfiguration** (role assignment, consent grant,
  public blob, legacy-auth bypass) — the cause.
- Proof of impact: data read from storage, token minted for a privileged principal, resource enumerated.
- Remediation: least privilege, remove legacy auth, enforce MFA/CA, rotate secrets, private storage.

## Pitfalls
- Cloud actions are heavily logged and attributable — stay in scope and minimal.
- MFA/Conditional Access blocking you is a **positive control** — report it as such, don't try to defeat it out of scope.
- Revoke tokens/sessions and remove any test app registrations or resources you created.
