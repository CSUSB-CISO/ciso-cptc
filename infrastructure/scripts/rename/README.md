# Hostname standardization scripts (2026-10-02)

Coach request: rename all 7 range VMs' Windows computer names to match their
inventory tag (`dc1`, `dc2`, `ca`, `web`, `sql1`, `sql2`, `workstation`), so
that combined with domain membership, FQDNs like `dc1.thelarpers.local` are
correct. All 7 hosts already have **static IPs confirmed via live audit**
(see table below) — renaming does not touch IP configuration, so no DHCP
work is required for this to be safe; it's being added to the `dhcp_server`
role separately just to formally reserve/document these addresses.

These were generated as standalone scripts (not run through Ansible, which
cannot reach `cptcnet` from the current control host). There are two ways
to run them — see "Fastest path" below for the recommended one (a single
script run from dc1 that handles 5 of the 7 hosts remotely over WinRM), and
"Fallback" for the original per-host approach (serve over HTTP from a box
like `kali-8` if it's dual-homed onto `cptcnet`, fetch + run on each VM's
own console). dc1 and dc2 themselves always need their own local two-phase
scripts regardless of which path you pick for the other 5.

**Why scripts instead of live noVNC console interaction**: this session hit
a confirmed noVNC keystroke bug where any `Shift`-chord character (symbols,
and apparently capital letters too) typed through the browser-automation
console gets silently dropped or corrupted. That makes multi-symbol
PowerShell (quotes, `$`, parentheses, the `:` in `netdom .../add:name`)
unreliable to type live. Scripts avoid this entirely — they're fetched and
executed as a file, no live keystroke-by-keystroke typing involved.

## Current state (audited live, 2026-10-02)

| Tag | VMID | Current hostname | IP (static) | MAC | Domain-joined? |
|-----|------|-------------------|--------------|-----|-----------------|
| dc1 | 320 | `WIN-TD79R6IO8IK` | 10.20.10.2/24 | BC-24-11-A8-CC-ED | Forest-root DC |
| dc2 | 321 | `WIN-9BC7MIABOGR` | 10.20.10.3/24 | BC-24-11-65-84-88 | Additional DC |
| ca | 322 | `WIN-JGUCB8I1UMC` | 10.20.10.4/24 | BC-24-11-13-1F-02 | Yes (domain_join role) |
| web | 323 | *(not yet audited — script doesn't need it)* | 10.20.10.5/24 | — | Yes (domain_join role) |
| sql1 | 324 | *(not yet audited)* | 10.20.10.6/24 | — | No (standalone) |
| sql2 | 325 | *(not yet audited)* | 10.20.10.7/24 | — | No (standalone) |
| workstation | 326 | *(not yet audited)* | 10.20.10.8/24 | — | Yes (domain_join role) |

Gateway/DNS for all 7: `10.20.10.1` (dc1) — dc2 also runs DNS post-promotion.

`Rename-Computer` doesn't require knowing a host's current name, so the
5 non-DC scripts work regardless of current state. Only the two DC scripts
needed the current name, which was confirmed live via `hostname`/`netdom
query dc` before writing them.

## Why dc1/dc2 are different (two-phase, netdom, not Rename-Computer)

`Rename-Computer` is **not supported** for a live, promoted domain
controller (Microsoft's own guidance) — it doesn't properly update the
computer's `NTDS Settings` object, SPNs, and DNS records the way `netdom`
does. The supported procedure is:

```
netdom computername <CurrentFQDN> /add:<NewFQDN>      (register the new name as an alias)
  ... wait for DNS replication ...
netdom computername <CurrentFQDN> /makeprimary:<NewFQDN>   (make it primary — requires reboot to take effect)
  ... reboot ...
netdom computername <NewFQDN> /remove:<OldFQDN>       (clean up the old name, post-reboot)
```

So each DC gets **two scripts**: `-phase1` (add, makeprimary, reboot) and
`-phase2` (remove old name — run *after* the reboot completes and you've
confirmed the new hostname is live, logged back in as
`thelarpers\Administrator`).

**Run dc1 and dc2 one at a time, not simultaneously** — rebooting both DCs
at once would leave the domain briefly without any DC to authenticate
against or replicate with. Finish dc1's phase1 → reboot → phase2 → verify
healthy (`netdom query dc`, `repadmin /replsummary`) before starting dc2.

## ca / web / workstation (domain-joined members)

These use plain `Rename-Computer`, but because the machine is domain-joined,
renaming it requires rights to update the computer object in AD — the
**local** Administrator account is not sufficient (this is almost certainly
why a live `Rename-Computer` attempt on `ca` this session failed with "The
user name or password is incorrect" — the local admin session had no rights
over the AD-side computer object). These scripts prompt interactively via
`Get-Credential` for the **domain** Administrator (`thelarpers\Administrator`)
at runtime — no password is embedded in the script, so it's safe to serve
over plain HTTP.

## sql1 / sql2 (standalone — not domain-joined)

Plain `Rename-Computer -Restart`, run as the local Administrator already
logged into the console. No domain credential needed.

## Fastest path: one orchestrator script, run from dc1

`rename-orchestrator-from-dc1.ps1` renames **ca, web, workstation, sql1,
and sql2 in one pass**, run from a single elevated PowerShell prompt on
dc1. dc1 already sits on `cptcnet` with every other host, and WinRM is
already configured for NTLM auth across the inventory (see `hosts.yml`) —
that's exactly the same path Ansible would use, just driven from dc1
instead of from outside the isolated network. No HTTP server needed for
this part at all; just fetch the one script onto dc1 and run it there.

It prompts interactively for the domain Administrator credential (used for
ca/web/workstation) and each of sql1/sql2's own local Administrator
credential (no passwords embedded), adds sql1/sql2 to dc1's WinRM
TrustedHosts list (required for NTLM to non-domain hosts), then uses
`Invoke-Command` to rename + restart each target. Prints a summary table
at the end.

**dc1 and dc2 are not included** — see the two-phase section above. Run
those locally on each DC, one at a time, before or after the orchestrator
pass (order between the DCs and the orchestrator doesn't matter, since
they're independent).

## Fallback: per-host scripts + HTTP server

If you'd rather not grant dc1 that much reach, or the orchestrator fails
on a particular host, the individual `rename-ca.ps1` / `rename-web.ps1` /
`rename-workstation.ps1` / `rename-sql1.ps1` / `rename-sql2.ps1` scripts
do the same work standalone, run directly on each host's own console.

On a host that can reach `cptcnet` (e.g. `kali-8` if dual-homed, or
whichever box can reach `10.20.10.0/24`):

```bash
cd infrastructure/scripts/rename
python3 -m http.server 8080
```

On each target VM, from an elevated PowerShell prompt:

```powershell
iwr -Uri http://<server-ip>:8080/rename-ca.ps1 -OutFile $env:TEMP\rename-ca.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\rename-ca.ps1
```

(Substitute the right script name per host.) Each script restarts the
computer itself at the end where a restart is needed — no separate reboot
step required.

## Verification after all renames

Re-run `verify-hostname.ps1` (also in this folder) on each host after its
reboot, or simply `hostname` + `ipconfig` — confirm the new short name
matches the inventory tag and the IP is unchanged from the table above.
Once all 7 are renamed, update `inventory/hosts.yml`'s `ansible_host`
comments if needed (IPs aren't changing, so no edits should be necessary)
and note completion in `CSUSB_CPTC_Range_Project_Baseline.md`.
