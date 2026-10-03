# Original to this range (no CyberHawks source file — LLMNR/NBT-NS
# poisoning is Windows' OWN default-enabled behavior; CyberHawks' own
# Stage 2 design for this finding is "don't harden it," not a script to
# port). See ../../../UPSTREAM.md. Idempotent: explicitly (re)sets the
# registry values to their enabled defaults, in case an earlier hardening
# pass (or a Windows baseline GPO) disabled them, so the finding reliably
# stays present rather than depending on whatever the image shipped with.
$ErrorActionPreference = "Stop"

# LLMNR: HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient
# EnableMulticast = 1 (or absent) means LLMNR is enabled (the default).
$dnsClientPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
if (Test-Path $dnsClientPolicyKey) {
    $current = (Get-ItemProperty -Path $dnsClientPolicyKey -Name EnableMulticast -ErrorAction SilentlyContinue).EnableMulticast
    if ($null -ne $current -and $current -ne 1) {
        Set-ItemProperty -Path $dnsClientPolicyKey -Name EnableMulticast -Value 1 -Type DWord
        Write-Output "Re-enabled LLMNR (EnableMulticast = 1)"
    } else {
        Write-Output "LLMNR already enabled (default)"
    }
} else {
    Write-Output "LLMNR already enabled (no policy override present = Windows default)"
}

# NBT-NS: enabled per network adapter via NetBT TcpipNetbiosOptions
# (0 = default/DHCP-controlled, 1 = enable, 2 = disable). Ensure no
# adapter has it explicitly disabled.
$netbtInterfacesKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
$changedAny = $false
if (Test-Path $netbtInterfacesKey) {
    Get-ChildItem $netbtInterfacesKey | ForEach-Object {
        $current = (Get-ItemProperty -Path $_.PSPath -Name NetbiosOptions -ErrorAction SilentlyContinue).NetbiosOptions
        if ($current -eq 2) {
            Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 0 -Type DWord
            $changedAny = $true
        }
    }
}
if ($changedAny) {
    Write-Output "Re-enabled NBT-NS on one or more adapters"
} else {
    Write-Output "NBT-NS already enabled (default) on all adapters"
}

Write-Output "DONE"
