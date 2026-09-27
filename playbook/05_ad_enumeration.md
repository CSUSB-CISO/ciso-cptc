# 05 — Authenticated Active Directory Enumeration

**Goal:** with a valid domain cred, map the domain and find shortest paths to high privilege.
BloodHound is the centerpiece; PowerView/LDAP/nxc fill gaps.

## Collect the BloodHound graph
```bash
bloodhound-python -d <DOMAIN> -u '<USER>' -p '<PASS>' -ns <DC_IP> -c All --zip   # remote, no code on target
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --bloodhound --collection All --dns-server <DC_IP>
SharpHound.exe -c All --zip                                                       # from Windows
# (Community Edition ingestor: rusthound / azurehound for cloud in 11)
```
Load the zip → run: *Shortest Paths to Domain Admins*, *Kerberoastable*, *AS-REP roastable*,
*Paths from Owned*, *Unconstrained/Constrained delegation*, *Find Computers where Domain Users are local admin*.

## PowerView (from a Windows foothold)
```powershell
Get-DomainUser -SPN | select samaccountname                    # kerberoastable
Get-DomainUser -PreauthNotRequired | select samaccountname     # asrep-roastable
Get-DomainUser -TrustedToAuth
Get-DomainComputer -Unconstrained | select name
Get-DomainComputer -TrustedToAuth | select name,msds-allowedtodelegateto
Find-InterestingDomainAcl -ResolveGUIDs | ? {$_.IdentityReferenceName -match '<owned>'}
Get-DomainObjectAcl -Identity <target> -ResolveGUIDs
Get-DomainGroupMember 'Domain Admins' -Recurse
Find-DomainShare -CheckShareAccess
Find-LocalAdminAccess                                          # where am I local admin
Get-DomainGPO ; Get-DomainGPOLocalGroup                        # GPO-granted local admin
Get-DomainTrust ; Get-ForestTrust                              # trusts (see 09)
```

## LDAP / netexec quick pulls
```bash
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --users
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --groups
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --admin-count
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --trusted-for-delegation
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --password-not-required
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' -M maq            # ms-DS-MachineAccountQuota (for RBCD)
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' -M adcs           # is AD CS present? (feeds 09)
ldapdomaindump -u '<DOMAIN>\<USER>' -p '<PASS>' <DC_IP>    # HTML/JSON dump of the directory
bloodyAD -d <DOMAIN> -u '<USER>' -p '<PASS>' --host <DC_IP> get writable   # objects you can write
```

## Priorities to pull out
- **Owned → DA paths** (the money shot) and **ACL edges**: GenericAll/GenericWrite/WriteDACL/WriteOwner/AddMember/ForceChangePassword.
- **Delegation**: unconstrained (coerce a DC), constrained, RBCD candidates (needs write + MAQ>0).
- **AD CS** present → `certipy find` (`09`).
- **Sessions**: where privileged users are logged in (lateral targets).
- **Stale / no-MFA / pwd-not-required / adminCount=1** accounts; service accounts; LAPS hosts.

## Evidence to capture
- Export the relevant BloodHound path as an image; screenshot the specific ACL/delegation/membership.

## Pitfalls
- `-c All` SharpHound is loud; scope collection if OPSEC matters.
- BloodHound shows *possible* paths — validate each edge before claiming it.
