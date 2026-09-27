# The Larpers — CPTC Attack Playbook

A local, phase-ordered field reference for practice and competition, in the spirit of
[ired.team](https://www.ired.team/) and [the hacker recipes](https://www.thehacker.recipes/).
It follows our engagement path top to bottom. Every command uses **swappable placeholders** —
replace them with your live targets before running.

> **Scope discipline first.** Only touch systems inside the written scope/ROE. CPTC is scored on
> findings quality, business impact, remediation, and professionalism — **not flag count**. Stay in
> scope, capture evidence as you go, and file incident reports promptly if something unexpected happens.

> **Provenance.** This playbook is authored as an original reference built around publicly known tools
> and techniques. It deliberately does **not** reproduce any paid-course text, lab walkthroughs, or
> exam-specific scenarios. Use it as a command/workflow reference; understand each command before running it.

---

## How to use
- Files are numbered in attack order. Start at `01`, move down. Jump around as the engagement dictates.
- Each phase lists: **Goal → Commands → What good evidence looks like → Common pitfalls.**
- `grep -ri "kerberoast" .` to jump straight to a technique.
- Copy a command, swap the placeholders, run it, paste the output into your notes/finding.

## Placeholder legend (find-and-replace these)
| Placeholder | Meaning | Example |
|---|---|---|
| `<ATTACKER_IP>` | Your Kali/attack host IP | 10.0.0.50 |
| `<ATTACKER_INT>` | Your attack interface | eth0 |
| `<TARGET_IP>` | A single target host | 10.0.0.10 |
| `<DC_IP>` | Domain controller IP | 10.0.0.5 |
| `<CA_IP>` | AD CS / CA host IP | 10.0.0.6 |
| `<SUBNET>` | In-scope range (CIDR) | 10.0.0.0/24 |
| `<DOMAIN>` | AD domain FQDN | corp.local |
| `<DOMAIN_NB>` | NetBIOS domain | CORP |
| `<DC_FQDN>` | DC hostname (FQDN) | dc01.corp.local |
| `<USER>` `<PASS>` | Credential pair | jdoe / Winter2026! |
| `<NTHASH>` | NT hash (PtH) | aad3b435...:31d6cfe0... |
| `<AESKEY>` | Kerberos AES256 key | — |
| `hosts.txt` `users.txt` | Your input lists | one per line |

## Working files convention (keep the engagement tidy)
```
loot/            # credentials, hashes, tickets, pfx
scans/           # nmap/masscan/nessus output (-oA into here)
evidence/        # screenshots, command transcripts, per-finding
notes/           # running log, per-host
```

## Core toolset (what our notes use)
Discovery/enum: `nmap`, `netexec (nxc)`, `enum4linux-ng`, `ldapsearch`, `smbclient/smbmap`, `BloodHound/SharpHound`, `PowerView`
Poisoning/relay: `Responder`, `mitm6`, `impacket-ntlmrelayx`
Credentials: `Rubeus`, `impacket-GetUserSPNs/GetNPUsers`, `hashcat`, `john`, `impacket-secretsdump`, `mimikatz`, `lsassy/nanodump`
AD CS: `certipy`, `Certify`
Privesc: `winPEAS/linPEAS`, `PowerUp`, `Seatbelt`, `SharpUp`
Lateral/exec: `impacket-psexec/wmiexec/smbexec`, `evil-winrm`, `impacket-mssqlclient`
Pivoting: `chisel`, `ligolo-ng`, `proxychains`
Web: `ffuf`, `gobuster`, `feroxbuster`, `sqlmap`, `Burp`, `nuclei`
Cloud (if in scope): `AzureHound`, `ROADtools`, `AADInternals`, `MicroBurst`, `o365spray`, `Pacu`, `ScoutSuite`

> **Can't find a command? Use the search box in the wiki, or `14_tool_index.md`.** Search now indexes
> every command line and tool name across all phases — e.g. searching `evil-winrm`, `nxc`, `kerberoast`,
> `esc1`, or `1433` returns every place it appears so you can pick your option.

## Attack path (file map)
1. `01_initial_access.md` — get a foothold / starting position
2. `02_recon_enumeration.md` — discover hosts, ports, services, DNS, unauth AD
3. `03_poisoning_relay.md` — Responder / mitm6 / NTLM relay → first creds & sessions
4. `04_credential_attacks.md` — spraying, AS-REP/Kerberoast, offline cracking, reuse
5. `05_ad_enumeration.md` — authenticated AD map (BloodHound/PowerView/LDAP)
6. `06_exploitation_foothold.md` — service exploitation, MSSQL, web-to-shell, shells
7. `07_privilege_escalation.md` — local Windows/Linux privesc
8. `08_lateral_movement.md` — PtH/PtT, exec methods, pivoting/tunneling
9. `09_ad_attacks_dominance.md` — delegation, ACLs, AD CS (ESC), DCSync, LAPS, tickets, trusts
10. `10_web_app.md` — web application testing (per-vuln quick reference)
11. `11_cloud_azure.md` — cloud / Entra ID / Azure / M365 (and AWS/GCP) — **only if in scope**
12. `12_data_hunting_exfil_impact.md` — find data, prove impact, exfil safely
13. `13_evidence_reporting.md` — evidence standard + finding writeup (ties to our templates)
14. `14_tool_index.md` — **A–Z arsenal**: search any tool/technique → what it is, phase, and commands
