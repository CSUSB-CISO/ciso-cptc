# dc2 — Manual Additional Domain Controller Promotion

**STATUS: COMPLETE (2026-10-02).** dc2 has been promoted and verified
healthy — `netdom query dc` lists both domain controllers, and
`repadmin /replsummary` shows 0 fails / 5 total (0% error) in both
directions. `dcdiag` passed every AD-specific test (partitions,
cross-ref validation, LocatorCheck, Intersite); its only reported
failure was a benign SystemLog warning about DNS lookups for Windows
Update domains timing out — expected, since dc2 is isolated on
`cptcnet` with no internet by design, not an AD health problem. dc2's
DNS is now pointed at itself + dc1 (`127.0.0.1,10.20.10.2`) per step 5
below. `inventory/hosts.yml` has been updated for the post-promotion
credential switch described at the bottom of this doc. The steps below
are kept as the record of what was run and as the runbook for any
future dc2 rebuild/re-promotion.

**Why manual, not Ansible:** the repo's `domain_controller` role uses
`microsoft.ad.domain`, which only creates a *new forest*. Pointing it at dc2
would try to stand up a second forest instead of joining dc2 to the one dc1
already created — corrupting the domain. A proper "join an existing forest as
an additional DC" Ansible role would need the `microsoft.ad.domain_controller`
module (a separate module from `microsoft.ad.domain`), which is a reasonable
future addition, but the coach decided (2026-10-02) to do this one-time,
one-host promotion manually instead of building and testing a new role for a
single host. If dc2 is ever rebuilt/re-cloned, re-run these same steps.

**Prereqs**
- dc1 has already been promoted and `{{ domain_dns_name }}` (see
  `group_vars/all.yml` — currently `thelarpers.local` / `THELARPERS`) exists and is
  reachable from dc2 over `cptcnet`.
- dc2's local Administrator password (`COACH_CREDENTIALS.md`).
- The domain Administrator (= dc1's local Administrator) credential, and a
  DSRM (Directory Services Restore Mode) password for dc2 — can be the same
  DSRM password used for dc1, or a new one; record whichever you choose in
  `COACH_CREDENTIALS.md`.

**Steps (run on dc2, as local Administrator)**

1. **Point dc2's DNS at dc1** (dc1 is the domain's DNS server):
   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet*" -ServerAddresses "10.20.10.2"
   ```
   Confirm dc2 can resolve the domain:
   ```powershell
   Resolve-DnsName thelarpers.local
   nltest /dsgetdc:thelarpers.local
   ```

2. **Install the AD DS role (and DNS, since dc2 will also be a DNS server):**
   ```powershell
   Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools
   ```

3. **Promote dc2 as an additional domain controller in the existing forest:**
   ```powershell
   Install-ADDSDomainController `
     -DomainName "thelarpers.local" `
     -Credential (Get-Credential THELARPERS\Administrator) `
     -SafeModeAdministratorPassword (ConvertTo-SecureString "<DSRM password>" -AsPlainText -Force) `
     -InstallDns `
     -CreateDnsDelegation:$false `
     -DatabasePath "C:\Windows\NTDS" `
     -LogPath "C:\Windows\NTDS" `
     -SysvolPath "C:\Windows\SYSVOL" `
     -NoRebootOnCompletion:$false `
     -Force:$true
   ```
   When prompted, enter dc1's domain Administrator password. The host reboots
   automatically when promotion completes.

4. **Verify after reboot** (log back in as `THELARPERS\Administrator`):
   ```powershell
   Get-ADDomainController -Filter * | Select-Object Name, IPv4Address, OperationMasterRoles
   repadmin /replsummary
   repadmin /showrepl
   dcdiag /v
   ```
   `repadmin /replsummary` should show 0 failures or 0% fail between dc1 and
   dc2 once the first replication cycle completes (can take a few minutes).

5. **Point dc2's own DNS at itself (or both DCs) once promoted**, so it
   doesn't have a hard dependency on dc1 being up:
   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet*" -ServerAddresses "127.0.0.1","10.20.10.2"
   ```

6. **Update `group_vars/all.yml`'s comment / this doc** if anything above
   deviated (DSRM password choice, OU placement, etc.), and record the DSRM
   password used for dc2 in `COACH_CREDENTIALS.md` if it differs from dc1's.

**After promotion, update the Ansible inventory login for dc2.** Once dc2 is
a domain controller, its local SAM database goes away — `inventory/hosts.yml`'s
`ansible_user: Administrator` / `ansible_password: {{ vault_dc2_admin_password }}`
for dc2 stops working, because "Administrator" is now the *domain* account,
not dc2's old local one. Change dc2's `ansible_password` to
`{{ vault_windows_admin_password }}` (the domain Administrator password,
already = dc1's original local Administrator password — see the comment at
the top of `inventory/hosts.yml`).

**After that, dc2 also picks up the `dhcp_server` role** (added 2026-10-02 —
see `site.yml` and `roles/dhcp_server`), which installs and authorizes DHCP
for `cptcnet` on dc2, so new hosts no longer need manual static-IP
configuration. DNS needs no separate step — dc2 already installs DNS above
via `-InstallDns`, and AD replicates the zone from dc1 automatically. No new
role is needed for OUs/users across both DCs (today `domain_controller`'s
OU/group/user tasks only target dc1, which is fine since AD replicates that
content to dc2 automatically).
