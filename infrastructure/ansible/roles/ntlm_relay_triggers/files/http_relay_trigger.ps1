# Adapted from CyberHawks cyber-range roles/ntlm_relay_triggers/files/http_relay_trigger.ps1
# (98307cc), owner permission 2026-10-03 -- see ../../../UPSTREAM.md.
#
# Simulates a scheduled sync job checking an internal file-sharing endpoint
# over HTTP/WebDAV. The hostname is deliberately a bare, unqualified name
# with no DNS record -- thelarpers.local's own DC is authoritative for the
# full "*.thelarpers.local" zone, so an FQDN here would get a definitive
# authoritative NXDOMAIN and Windows would never fall back to broadcast
# resolution. A single-label name still fails DNS (via suffix search) but
# *does* fall through to LLMNR/NBT-NS/mDNS afterward -- whoever answers
# that broadcast gets a live NTLMv2 authentication attempt from this task's
# Run As identity, ripe for capture or live relay to LDAP on a DC.
try {
    Invoke-WebRequest -Uri "http://filesvc/sync/" -UseDefaultCredentials -UseBasicParsing -TimeoutSec 8 | Out-Null
} catch {
    # Expected to fail every time -- the outbound NTLM auth attempt is the
    # point, not a successful response.
}
