$ErrorActionPreference = "Stop"

# Adapted from the ESC8 confirmation block in CyberHawks cyber-range
# roles/adcs_esc_templates/files/ca_config_early.ps1 (98307cc), owner
# permission 2026-10-03 -- see ../../../UPSTREAM.md. ESC8 doesn't need
# anything BUILT here: roles/adcs_ca already installs the Web Enrollment
# role service (/certsrv) over plain HTTP with no extra TLS/auth hardening,
# which is itself the ESC8 misconfig (NTLM-relayable HTTP enrollment). This
# just confirms that's still true, the same way the rest of this build
# confirms (rather than assumes) security-relevant defaults haven't drifted.

try {
    $resp = Invoke-WebRequest -Uri "http://localhost/certsrv/" -UseBasicParsing -UseDefaultCredentials -ErrorAction Stop
    Write-Output "ESC8: Web Enrollment reachable over plain HTTP (status $($resp.StatusCode))"
} catch {
    Write-Output "ESC8: Web Enrollment check returned: $($_.Exception.Message)"
}
