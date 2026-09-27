# 02 — Recon & Enumeration

**Goal:** a complete, evidence-backed picture before attacking — live hosts, ports, services/versions,
DNS, SMB, and as much AD as you can get. Enumeration quality decides everything downstream.

## Host discovery
```bash
nmap -sn -PE -iL hosts.txt -oA scans/pingscan            # ICMP sweep (often filtered internally)
# No-ping TCP discovery for large/filtered ranges
nmap -vv -sS -Pn -T4 --min-hostgroup 128 --max-retries 1 \
  -p 21,22,23,25,53,80,88,110,111,135,139,143,389,443,445,465,636,993,995,1433,1720,3306,3389,5985,8000,8080,8443 \
  -iL hosts.txt -oA scans/tcp_discovery
# Very large scopes: masscan first, then nmap the hits
masscan -p1-65535 <SUBNET> --rate 10000 -oL scans/masscan.txt
fping -a -g <SUBNET> 2>/dev/null                          # quick alive list
netdiscover -r <SUBNET>                                    # ARP sweep (local segment)
```
Extract live hosts: `grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' scans/tcp_discovery.gnmap | sort -u > scans/live.txt`

## Port & service scanning
```bash
nmap -p- -sS -Pn -T4 --min-rate 2000 -iL scans/live.txt -oA scans/tcp_full
nmap -sV -sC -Pn -p <ports> -iL scans/live.txt -oA scans/tcp_services
nmap -sU -Pn --top-ports 100 -iL scans/live.txt -oA scans/udp_top
# Targeted script scans
nmap -Pn -p445 --script smb-protocols,smb2-security-mode <TARGET_IP>
nmap -Pn -p88  --script krb5-enum-users --script-args krb5-enum-users.realm='<DOMAIN>' <DC_IP>
```

## DNS
```bash
nslookup -type=SRV _ldap._tcp.dc._msdcs.<DOMAIN> <DC_IP>  # find DCs
dig @<DC_IP> SRV _kerberos._tcp.<DOMAIN>
dig @<DC_IP> AXFR <DOMAIN>                                 # zone transfer (usually refused)
dnsrecon -d <DOMAIN> -n <DC_IP> -t std,srv
adidnsdump -u '<DOMAIN>\<USER>' -p '<PASS>' <DC_IP>        # dump AD-integrated DNS (auth'd)
```

## SMB / NetBIOS / shares (top early-win source)
```bash
nxc smb <SUBNET>                                           # OS, hostname, domain, signing
nxc smb <SUBNET> --gen-relay-list scans/no_signing.txt    # signing OFF = relay targets (feeds 03)
nxc smb <TARGET_IP> -u '' -p '' --shares                  # null session
nxc smb <TARGET_IP> -u 'guest' -p '' --shares
smbmap -H <TARGET_IP> -u guest -p ''
smbclient -L //<TARGET_IP>/ -N
smbclient //<TARGET_IP>/<SHARE> -N
enum4linux-ng -A <TARGET_IP>
```

## Unauthenticated / low-priv AD enumeration
```bash
nxc smb  <DC_IP> -u '' -p '' --pass-pol                    # password policy (before spraying!)
nxc smb  <DC_IP> -u 'guest' -p '' --rid-brute              # pull usernames via RID cycling
nxc ldap <DC_IP> -u '' -p '' --users                       # anonymous LDAP (sometimes allowed)
ldapsearch -x -H ldap://<DC_IP> -b "DC=<dc>,DC=<dc>" -s sub "(objectClass=user)" sAMAccountName
kerbrute userenum -d <DOMAIN> --dc <DC_IP> users.txt       # validate usernames via Kerberos (no creds)
windapsearch -d <DOMAIN> --dc <DC_IP> -U                   # users/groups over LDAP
```

## Other services worth a look
- **NFS**: `showmount -e <TARGET_IP>` → mount and read exports.
- **SNMP**: `snmpwalk -v2c -c public <TARGET_IP>` (community strings leak a lot).
- **RPC**: `rpcclient -U '' -N <TARGET_IP>` → `enumdomusers`, `querydispinfo`.
- **MSSQL/MySQL/Postgres/Redis/Mongo**: note versions + try default/blank auth (`06`).

## Evidence to capture
- `-oA` every nmap into `scans/`. Keep an **asset inventory table**: host, IP, OS, key services, notes.
- Screenshot notable finds (open share, null session, zone transfer).

## Pitfalls
- ICMP-only discovery misses hosts — always follow with a TCP discovery pass.
- Verify CIDRs against the SOW; never scan out of scope.
- Dial back `-T5`/high `--min-rate` on OT/legacy/fragile gear.
