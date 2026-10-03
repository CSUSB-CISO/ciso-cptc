<#
  Run this ON dc1, logged in as thelarpers\Administrator, from an elevated
  PowerShell prompt. dc1 sits on cptcnet (10.20.10.0/24) alongside every
  other range host, so it can reach all of them over WinRM in one pass --
  no need to log into each host's own console individually.

  Renames the 5 NON-DOMAIN-CONTROLLER hosts in one shot:
    ca, web, workstation  (domain-joined -- renamed using the domain
                            Administrator credential, which already has
                            rights over the AD computer object)
    sql1, sql2            (standalone/workgroup -- renamed using each
                            host's own local Administrator credential)

  dc1 and dc2 are deliberately NOT included here. Rename-Computer is not
  supported on a live domain controller (must use the netdom add /
  makeprimary / remove procedure instead -- see rename-dc1-phase1.ps1 /
  rename-dc2-phase1.ps1 in this folder), and remotely triggering a DC's
  rename+reboot from a script risks leaving the domain without a healthy
  DC to coordinate against if anything goes wrong mid-sequence. Handle
  dc1/dc2 one at a time, locally, watching dcdiag/repadmin between steps.

  Each target host reboots itself immediately after the rename is issued.
  Static IPs are untouched by any of this -- only the computer name changes.
#>

$ErrorActionPreference = 'Stop'

Write-Host "=== CPTC range hostname standardization (ca/web/workstation/sql1/sql2) ===" -ForegroundColor Cyan
Write-Host "Run from: $(hostname)   Expected: dc1 (or its current pre-rename name)"
Write-Host ""

# Credential for the 3 domain-joined hosts (ca, web, workstation).
# Renaming a domain-joined computer updates its AD computer object, which
# the LOCAL Administrator account on that box has no rights to do -- only
# a domain credential with rights over the object (the domain Administrator
# is simplest) can. No password is embedded here; typed interactively.
$domainCred = Get-Credential -Message "Domain Administrator (thelarpers\Administrator) -- used for ca, web, workstation"

# Credentials for the 2 standalone hosts (sql1, sql2). These are NOT
# domain members, so WinRM auths to them with each host's own local
# Administrator account over NTLM, same as Ansible's inventory does.
$sql1Cred = Get-Credential -Message "Local Administrator credential for sql1 (10.20.10.6)"
$sql2Cred = Get-Credential -Message "Local Administrator credential for sql2 (10.20.10.7)"

# WinRM (NTLM) to non-domain hosts requires the caller to trust them by
# name/IP first -- same reason hosts.yml sets ansible_winrm_transport: ntlm
# for sql1/sql2. This only affects outbound connections FROM dc1.
Write-Host "Adding sql1/sql2 to this host's WinRM TrustedHosts list..."
$existing = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
$needed   = @('10.20.10.6', '10.20.10.7')
$combined = (@($existing) + $needed | Where-Object { $_ -and $_ -ne '' } | Select-Object -Unique) -join ','
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $combined -Force

$targets = @(
    [pscustomobject]@{ Name = 'ca';          IP = '10.20.10.4'; Cred = $domainCred },
    [pscustomobject]@{ Name = 'web';         IP = '10.20.10.5'; Cred = $domainCred },
    [pscustomobject]@{ Name = 'workstation'; IP = '10.20.10.8'; Cred = $domainCred },
    [pscustomobject]@{ Name = 'sql1';        IP = '10.20.10.6'; Cred = $sql1Cred },
    [pscustomobject]@{ Name = 'sql2';        IP = '10.20.10.7'; Cred = $sql2Cred }
)

$results = @()

foreach ($t in $targets) {
    Write-Host ""
    Write-Host "--- $($t.Name) ($($t.IP)) ---" -ForegroundColor Yellow

    # Quick reachability check before attempting the real work, so one
    # unreachable host doesn't just hang the whole run.
    try {
        Test-WSMan -ComputerName $t.IP -Credential $t.Cred -Authentication Negotiate -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "  WinRM not reachable/authenticating on $($t.Name) ($($t.IP)): $($_.Exception.Message)"
        $results += [pscustomobject]@{ Host = $t.Name; IP = $t.IP; Status = "UNREACHABLE" }
        continue
    }

    try {
        $out = Invoke-Command -ComputerName $t.IP -Credential $t.Cred -Authentication Negotiate -ScriptBlock {
            param($newName)
            $current = (hostname)
            if ($current -ieq $newName) {
                return "ALREADY-NAMED:$current"
            }
            Rename-Computer -NewName $newName -Force -Restart
            return "RENAME-ISSUED:$current->$newName"
        } -ArgumentList $t.Name -ErrorAction Stop

        Write-Host "  $out" -ForegroundColor Green
        $results += [pscustomobject]@{ Host = $t.Name; IP = $t.IP; Status = $out }
    } catch {
        Write-Warning "  FAILED on $($t.Name): $($_.Exception.Message)"
        $results += [pscustomobject]@{ Host = $t.Name; IP = $t.IP; Status = "FAILED: $($_.Exception.Message)" }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host ""
Write-Host "Hosts with RENAME-ISSUED are rebooting now. Give them ~2 minutes, then verify" -ForegroundColor Cyan
Write-Host "each one with: Test-Connection <ip> -Count 2 ; then log in and run hostname/ipconfig" -ForegroundColor Cyan
Write-Host "(or iwr the verify-hostname.ps1 script in this folder onto each host)." -ForegroundColor Cyan
Write-Host ""
Write-Host "dc1 and dc2 are NOT handled by this script -- run their dedicated" -ForegroundColor Cyan
Write-Host "rename-dc1-phase1.ps1 / rename-dc2-phase1.ps1 locally on each, one at a time." -ForegroundColor Cyan
