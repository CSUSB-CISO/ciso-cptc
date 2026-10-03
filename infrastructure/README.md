# cptc-2026-infrastructure — The Larpers CPTC Training Range

Infrastructure-as-code for the CSUSB **The Larpers** CPTC training range: a safe,
repeatable, **isolated** Active Directory range on Proxmox, provisioned with
**Terraform** and configured with **Ansible**. Built to grow in stages — the MVP
teaches scope, discovery, AD basics, and evidence discipline with **zero exploits
enabled**; later stages switch on intentional vulnerabilities via a single
`vuln_stage` variable.

**Themed to the CPTC12 (2026–27) scenario — "Butters Family Farm,"** an aging
family-owned theme park (rides, attractions, patron operations), with a
`ParkOps` database (rides, patrons, season passes, maintenance tickets,
vendors). The AD domain itself is the team's own range identity — RESOLVED
2026-10-02: `thelarpers.local` / NetBIOS `THELARPERS` — intentionally
decoupled from the in-universe `company_name`. It's a *training analogue* for
practice, **not** the real competition environment.

> **Isolation is mandatory.** This range must never touch the campus network or
> the public Internet. See `scripts/isolation_test.sh` and the runbook.

> **Licensing / provenance.** This repo is **original work** that uses the
> CyberHawks `cyber-range` as a *reference architecture only* (it has no license —
> all rights reserved). The intentional-vulnerability roles are **stubs** pending
> the owner's explicit written permission. `AttackerVMs` (MIT) is adapted with
> attribution. See `UPSTREAM.md`.

## What this builds (MVP — `vuln_stage: 1`)

| VM | Role | OS (your media) | vCPU | RAM | Disk |
|---|---|---|---|---|---|
| `dc1` | Domain Controller + DNS (forest root) | Server 2019 | 2 | 4 GB | 60 GB |
| `sql1` | SQL Server 2019 Developer + benign business DB | Server 2019 | 2 | 6 GB | 80 GB |
| `ws1` | Domain-joined Windows 11 client (persona) | Win11 Enterprise | 2 | 4 GB | 60 GB |
| `kali` | Attacker (from `cptc-2026-attacker-vms`) | Kali 2026.2 | 2 | 4 GB | 40 GB |

Everything is **variable-driven** — domain, subnet, hostnames, VM IDs, template
IDs, branding, and `vuln_stage` all live in `ansible/group_vars/all.yml` and
`terraform/terraform.tfvars`. Nothing about "CyberHawks" is hardcoded.

## The two-step workflow

```
1) terraform apply     # clones the 4 VMs from your Proxmox templates, sets IPs
2) ansible-playbook site.yml   # promotes the DC, builds AD, installs SQL, seeds data, joins ws1
```

Then validate, snapshot, and you're ready for exercises:

```
3) ansible-playbook validate.yml     # confirms domain, users, shares, DB rows
4) scripts/snapshot.sh stage1-clean  # named known-good snapshot for fast reset
```

## Repo layout

```
terraform/           # Proxmox provisioning (bpg/proxmox provider)
ansible/
  inventory/hosts.yml
  group_vars/all.yml         # ← the one file coaches edit most
  group_vars/vault.example.yml
  site.yml                   # full build
  validate.yml               # post-build checks
  roles/
    common_prereqs/          # WinRM/host prep, static IP sanity
    domain_controller/       # AD DS + DNS + OUs/users/groups/GPO + SMB shares
    domain_join/             # join ws1 to the domain
    mssql_server/            # SQL 2019 Developer install + benign business DB
    business_data/           # synthetic business dataset (Employees, Invoices, …)
    ad_base_accounts/        # Stage 2: weak/spray passwords, AS-REP, Kerberoast (dc1)
    ad_misc_findings/        # Stage 2: GPP cpassword + SMB credential exposure (dc1)
    dns_zone_transfer/       # Stage 2: unauthenticated AXFR (dc1)
    smb_file_dump/           # Stage 2: world-readable share dumps (web, workstation)
    workstation_privesc/     # Stage 2: weak svc perms/unquoted path/PATH dir, LLMNR (workstation)
    local_admin_reuse/       # Stage 2: shared local admin password (workstation/sql1/sql2/web)
    _vuln_stubs/             # placeholders for Stage 3–4 only (mssql_misconfig, adcs_esc)
scripts/             # snapshot.sh, reset.sh, isolation_test.sh
docs/                # BUILD_RUNBOOK.md
REQUIRED_INPUTS.md   # ← what I need from you to actually stand this up
UPSTREAM.md          # provenance + licensing
```

## Before you start

Read **`REQUIRED_INPUTS.md`** — it lists the Proxmox access, template IDs,
network details, and decisions needed to run this. Fill in
`terraform/terraform.tfvars` and `ansible/group_vars/all.yml`, create the Ansible
Vault, and follow `docs/BUILD_RUNBOOK.md`.

## Staging model

`vuln_stage` gates what Ansible enables:

| Stage | Adds | Status here |
|---|---|---|
| 1 | AD/DNS, users/groups/OUs/GPO, SMB shares, **benign** business DB | ✅ built |
| 2 | Weak passwords, AS-REP/Kerberoast, LLMNR, local-admin reuse | ⛔ stub (needs permission or original re-impl) |
| 3 | IIS portal, SQL misconfig, linked server, more personas | ⛔ stub |
| 4 | dc2, ADCS (ESC), delegation, LAPS, NTLM relay/coercion | ⛔ stub |
| 5 | Mock engagement (SOW/ROE/injects) — docs, no new automation | planned |
| 6 | GOAD-Light / full GOAD — separate isolated deployment | planned |
