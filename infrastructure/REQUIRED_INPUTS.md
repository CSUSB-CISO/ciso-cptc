# Required inputs & access — what I need from you to stand this up

Fill these in and the range builds end-to-end. Grouped by "must have to build at
all" vs. "decisions with proposed defaults you can keep." Anything marked
**[PROPOSAL]** already has a working default in the config — change it or keep it.

---

## A. Proxmox access (required — the build can't run without these)

| # | Item | Where it goes | Notes |
|---|---|---|---|
| A1 | Proxmox API URL | `terraform.tfvars` → `proxmox_endpoint` | e.g. `https://192.168.192.150:8006/` |
| A2 | Proxmox **API token** (id + secret) | `terraform.tfvars` / env `PROXMOX_VE_API_TOKEN` | Create a token for an automation user with VM.Allocate/Clone/Config. **Don't commit it.** |
| A3 | Proxmox node name | `terraform.tfvars` → `proxmox_node` | e.g. `pve` (see `pvesh get /nodes`) |
| A4 | Storage pool for VM disks | `terraform.tfvars` → `proxmox_storage` | e.g. `local-lvm` |
| A5 | SSH access to the Proxmox host (key) | control host | Needed for `qm` commands, snapshots, cloud-init cred dump |

## B. VM templates (required — Terraform clones these)

You need cloud-init/**cloudbase-init** templates already built on Proxmox. This
repo clones them; it does **not** build them (see runbook for a template-build
checklist). Provide the template VM IDs:

| # | Item | Variable | Your value |
|---|---|---|---|
| B1 | Windows Server 2019 template ID | `template_ids.win2019` | ? |
| B2 | Windows 11 Enterprise template ID | `template_ids.win11` | ? |
| B3 | Kali 2026.2 template ID (or build from `cptc-2026-attacker-vms`) | `template_ids.kali` | ? |
| B4 | (later) Server 2016 / 2025 template IDs | `template_ids.win2016/2025` | for Stage 3–4 |

> Your ISO folder already has Server 2016/2019/2025, Win11 Enterprise, and Kali
> media — those feed the **template build**, a one-time prerequisite.

## C. Network / isolation (required)

| # | Item | Variable | [PROPOSAL] default |
|---|---|---|---|
| C1 | Isolated Proxmox bridge for the range | `proxmox_bridge` | **[PROPOSAL]** `vmbr-range` (isolated, no uplink) |
| C2 | Range subnet (CIDR) | `ip_network` | **[PROPOSAL]** `10.20.10.0/24` |
| C3 | Gateway (or none, if fully isolated) | `gateway` | **[PROPOSAL]** `10.20.10.1` |
| C4 | How coaches/students reach the range | runbook | **Palo Alto GlobalProtect** (team has access) → management network → range |

> **Decision (C4) — access via GlobalProtect.** Reviewed cp.tc: CPTC **does not dictate**
> how competitors access the target network, so this is your training-range choice, and
> the team has **Palo Alto GlobalProtect**. Recommended design: GP terminates users on a
> **management network**; the range VMs sit on an **isolated bridge with no uplink**.
> Because GP uses interactive SSO/MFA, prefer a **build host that reaches Proxmox
> *without* GP** (lab LAN) and use GP for student access. If GP can route to the range
> subnet directly you may not need a jump host; if it lands on a management net only,
> add a small **dual-homed jump host** (mgmt NIC + isolated range NIC) — also more
> competition-realistic. See `docs/LAB_INTAKE_QUESTIONNAIRE.md` §0. Isolation is enforced
> at the bridge either way.

## D. Secrets (required — via Ansible Vault, never committed)

| # | Item | Where | Notes |
|---|---|---|---|
| D1 | Shared local/domain Administrator password | `group_vars/vault.yml` → `vault_windows_admin_password` | Set at template/cloud-init time; retrieve with `qm cloudinit dump <vmid> user` |
| D2 | SQL `sa` password | `vault.yml` → `vault_mssql_sa_password` | Mixed-mode; strong, lab-only |
| D3 | Directory Services Restore Mode (DSRM) password | `vault.yml` → `vault_dsrm_password` | Required to promote the DC |
| D4 | Vault password itself | `~/.ansible-secrets/larpers_vault_pass` | Referenced by `ansible.cfg`; never committed |

## E. Software you must supply (licensing / download)

| # | Item | Notes |
|---|---|---|
| E1 | **SQL Server 2019 Developer** installer | Your `MSSQL2019.exe` is the **Evaluation** stub (expires 180 days). Download the **Developer** stub instead — free, full-featured, no expiry. Place ISO/exe where the `mssql_server` role expects (see role defaults). |
| E2 | SSMS (optional) | For manual DB inspection |
| E3 | CyberHawks reuse permission | **[BLOCKER for Stage 2–4]** Explicit written OK from the repo owner, or a LICENSE added to `cyber-range`. MVP does **not** need this. |

## F. Decisions with proposed defaults (change in `group_vars/all.yml`)

All are **[PROPOSAL]s** — the range builds fine as-is; edit to taste.

| # | Decision | Variable | [PROPOSAL] default |
|---|---|---|---|
| F1 | Fictional company name | `company_name` | **`Butters Family Farm`** (CPTC12 theme — theme-park operator) |
| F2 | AD domain (DNS) | `domain_dns_name` | `buttersfarm.lab` |
| F3 | NetBIOS name | `domain_netbios` | `BUTTERS` |
| F4 | Hostnames | `hosts.*` | `dc1`, `sql1`, `ws1`, `kali` |
| F5 | Static IPs | `hosts.*.ip` | `.10` dc1, `.20` sql1, `.50` ws1, `.100` kali |
| F6 | # Win11 endpoints | add to `hosts` map | 1 for MVP (2–4 personas at Stage 3) |
| F7 | Workstation persona | `ws1.persona` | `guest_services` (theme-park personas incl. rides_ops, maintenance, finance, it, exec) |
| F8 | SQL instance name | `mssql_instance_name` | `MSSQLSERVER` (default instance) |
| F9 | Branding | `branding_*` | `The Larpers` · Coyote Blue `#0065BD` |
| F10 | Vulnerability stage | `vuln_stage` | `1` (MVP, no exploits) |

---

## Fastest path to "yes, it's building"

1. Give me **A1–A5** (Proxmox endpoint, token, node, storage, SSH) and **B1–B3**
   (template IDs). That's the true minimum.
2. Confirm or override **C1–C3** (bridge/subnet) and **C4** (VPN vs jump host).
3. Set the four **D** secrets in Vault.
4. Download **E1** (SQL Developer).
5. Keep or tweak the **F** proposals.

With A + B + D in hand I can (if you want) run the build against your Proxmox from
here, or hand you the exact commands to run yourself.
