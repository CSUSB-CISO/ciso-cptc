<#
  Run this ON dc1, logged in as thelarpers\Administrator, from an elevated
  PowerShell prompt -- same pattern as rename-orchestrator-from-dc1.ps1.

  Why this is needed: a fresh Windows Server/11 install does NOT enable the
  "File and Printer Sharing" (SMB) inbound firewall rules by default. dc1
  and dc2 only have SMB open because AD DS/domain-controller promotion
  auto-configures those rules for SYSVOL/NETLOGON -- it was never applied
  to ca/web/sql1/sql2/workstation. Confirmed live on ca (2026-10-02):
  port 445 was listening locally, network profile was DomainAuthenticated
  (not the stricter Public profile), but
    Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -Enabled True
  returned zero rules -- nothing was open to the network. Fixed on ca by
  running:
    Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing'
  which brought the SMB-In rule to Enabled: True and made ca visible to
  netexec. This script applies the identical fix to the remaining 4 hosts
  in one pass from dc1, the same way rename-orchestrator-from-dc1.ps1 did
  the renames -- so nobody has to hand-type quoted/braced PowerShell on
  each host's own console (this environment has a noVNC keystroke bug that
  drops/corrupts Shift-chord characters).

  ca itself is NOT included below since it's already confirmed fixed.
  dc1 and dc2 are not included either -- they already have SMB open via
  DC promotion.
#>

$ErrorActionPreference = 'Stop'

Write-Host "=== Enable File and Printer Sharing (SMB) inbound rules: web/sql1/sql2/workstation ===" -ForegroundColor Cyan
Write-Host "Run from: $(hostname)   Expected: dc1"
Write-Host ""

# Same credential pattern as rename-orchestrator-from-dc1.ps1.
$domainCred = Get-Credential -Message "Domain Administrator (thelarpers\Administrator) -- used for web, workstation"
$sql1Cred   = Get-Credential -Message "Local Administrator credential for sql1 (10.20.10.6)"
$sql2Cred   = Get-Credential -Message "Local Administrator credential for sql2 (10.20.10.7)"

Write-Host "Adding sql1/sql2 to this host's WinRM TrustedHosts list (if not already present)..."
$existing = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
$needed   = @('10.20.10.6', '10.20.10.7')
$combined = (@($existing) + $needed | Where-Object { $_ -and $_ -ne '' } | Select-Object -Unique) -join ','
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $combined -Force

$targets = @(
    [pscustomobject]@{ Name = 'web';         IP = '10.20.10.5'; Cred = $domainCred },
    [pscustomobject]@{ Name = 'workstation'; IP = '10.20.10.8'; Cred = $domainCred },
    [pscustomobject]@{ Name = 'sql1';        IP = '10.20.10.6'; Cred = $sql1Cred },
    [pscustomobject]@{ Name = 'sql2';        IP = '10.20.10.7'; Cred = $sql2Cred }
)

$results = @()

foreach ($t in $targets) {
    Write-Host ""
    Write-Host "--- $($t.Name) ($($t.IP)) ---" -ForegroundColor Yellow

    try {
        Test-WSMan -ComputerName $t.IP -Credential $t.Cred -Authentication Negotiate -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "  WinRM not reachable/authenticating on $($t.Name) ($($t.IP)): $($_.Exception.Message)"
        $results += [pscustomobject]@{ Host = $t.Name; IP = $t.IP; Status = "UNREACHABLE" }
        continue
    }

    try {
        $out = Invoke-Command -ComputerName $t.IP -Credential $t.Cred -Authentication Negotiate -ScriptBlock {
            $before = (Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -Enabled True -ErrorAction SilentlyContinue | Measure-Object).Count
            Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing'
            $rule = Get-NetFirewallRule -DisplayName 'File and Printer Sharing (SMB-In)'
            return "SMB-In Enabled=$($rule.Enabled)  (rules enabled before fix: $before)"
        } -ErrorAction Stop

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
Write-Host "ca was already fixed and confirmed manually. dc1/dc2 don't need this (SMB" -ForegroundColor Cyan
Write-Host "already open via DC promotion). After this completes, re-run from kali-8:" -ForegroundColor Cyan
Write-Host "  netexec smb 10.20.10.0/24" -ForegroundColor Cyan
Write-Host "to confirm all 7 hosts now respond." -ForegroundColor Cyan
