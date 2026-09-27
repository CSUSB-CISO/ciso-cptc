# 01 — Initial Access

**Goal:** get a starting position on the target network and turn it into a first credential or session.
In CPTC this is usually an **assumed-breach / internal** posture (a drop on a segment, sometimes a
low-priv account). External-facing footholds (exposed web app, default creds on a service) also appear.

## Decide your starting state → where to go next
| You have… | Go to |
|---|---|
| A network drop, **no creds** | `02` recon → `03` poisoning/relay (the classic zero-to-cred path) |
| A **low-priv domain user** | `04` credential attacks + `05` AD enumeration |
| An **exposed service / web app** | `06` exploitation / `10` web app |
| **Local admin** on a box | `04` dump secrets → `08` lateral movement |
| Anything in **Azure/Entra/M365** | `11` cloud |

## Validate a credential before you build on it
```bash
# netexec (nxc = successor to crackmapexec). Try each protocol you care about.
nxc smb   <DC_IP> -u '<USER>' -p '<PASS>'
nxc smb   <SUBNET> -u '<USER>' -p '<PASS>' --continue-on-success   # spray one cred across a range
nxc ldap  <DC_IP> -u '<USER>' -p '<PASS>'
nxc winrm <TARGET_IP> -u '<USER>' -p '<PASS>'
nxc mssql <TARGET_IP> -u '<USER>' -p '<PASS>'
nxc rdp   <TARGET_IP> -u '<USER>' -p '<PASS>'
# Hash instead of password (pass-the-hash)
nxc smb <SUBNET> -u '<USER>' -H '<NTHASH>' --continue-on-success
# Kerberos ticket
export KRB5CCNAME=<USER>.ccache; nxc smb <DC_FQDN> --use-kcache
```
`(Pwn3d!)` next to a host = you're **local admin** there.

## Common internal entry points to check first
- **NAC / 802.1x** — are you even allowed on the wire, or quarantined? (a control that works = a finding either way)
- **Anonymous / guest SMB & shares** (`02`)
- **Default creds** on printers, iDRAC/iLO/IPMI, Jenkins, Tomcat/manager, GitLab, databases, web admin panels
- **Unauthenticated web apps / intranet portals** (`10`)
- **Legacy protocols** enabled: LLMNR/NBT-NS, IPv6/WPAD (`03`)

## Phishing / client-side (only if explicitly in scope)
CPTC is usually assumed-breach; social engineering is allowed **only when scoped**. If it is:
HTA/LNK/ISO/macro lures, `msfvenom`/your C2 stager, and credential-capture pages. Keep specifics in
your own lab notes and confirm scope in writing first.

## Evidence to capture
- Exact command + timestamp + the host it targeted, and how you obtained the credential.
- Screenshot of the first successful auth (`[+]`).
- Business meaning: what system/data this access represents.

## Pitfalls
- Re-read the SOW/ROE before touching anything; don't reuse creds against out-of-scope hosts.
- Log everything now — you won't reconstruct the order later.
