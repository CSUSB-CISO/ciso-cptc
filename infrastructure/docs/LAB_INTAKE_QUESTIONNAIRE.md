# Lab Intake Questionnaire — automate as much of the build as possible

Answer these and the Terraform + Ansible can be filled in end-to-end. Each item
notes **where the answer goes** (variable / file) so it drops straight into config.
Priority: **[P0]** = build can't run without it · **[P1]** = needed before students ·
**[P2]** = nice-to-have / later stage.

Legend for "feeds": `tfvars` = terraform/terraform.tfvars · `all.yml` =
ansible/group_vars/all.yml · `vault` = ansible/group_vars/vault.yml · `inv` =
ansible/inventory/hosts.yml.

---

## 0. VPN & access model  ⭐ (confirmed: **Palo Alto GlobalProtect**)

> GlobalProtect note: GP typically uses **SAML/SSO + MFA** and an interactive client,
> so a **headless, unattended "connect-and-build"** is hard. The clean pattern is to
> reach **Proxmox without GP** for building, and use **GP only for student range
> access**. These questions confirm which applies.

- **[P0]** Once GP is connected, can it reach the **Proxmox management IP/API (8006)**
  and **SSH (22)**? — *decides whether builds can run over GP at all*
- **[P0]** Is there a path to Proxmox that **doesn't** need GP (you're on the lab/campus
  LAN, or a wired mgmt network)? **Strongly preferred for the build host.** — *decides build-host placement*
- **[P1]** GP **split-tunnel or full-tunnel**? If full-tunnel, does it still allow the
  build host to reach Proxmox + package registries (pip/galaxy/terraform providers)
  during a build? — *runbook / build-host*
- **[P1]** GP auth method — **SAML/SSO, cert, or user/pass** — and **MFA**? How often
  does it re-prompt? (SAML+MFA = interactive; rules out zero-touch scheduled builds.) — *automation ceiling*
- **[P1]** Which **GP gateway/portal** and is there a **specific profile** we should
  use for the range? Who administers GP (campus IT?) and can we get a **lab/service
  account**? — *ops*
- **[P1]** Does GP place connected users on a network that can **route to the isolated
  range subnet** (`10.20.10.0/24` by default), or onto a **management network** from
  which they'd reach a **jump host**? (You chose VPN — this decides if we still need a
  jump box, and whether the range bridge needs a routed mgmt interface.) — *network design*
- **[P1]** Any **GP HIP / posture checks** (device compliance) that would block a
  Linux build host or the students' Kali? — *build-host / student access*
- **[P2]** GP client OS for the build host: **Windows/macOS GUI** (simplest — connect,
  then run one command) vs **Linux** (needs `openconnect --protocol=gp`, plus a SAML
  helper if SSO — more setup, still not fully unattended with MFA)? — *build-host design*
- **[P2]** Any GP/firewall **ACLs** that would block the range subnet or the Proxmox
  API port from VPN clients? — *network*

## 1. Proxmox host & API  [P0]

- **[P0]** Proxmox API URL (e.g. `https://<ip>:8006/`). — *tfvars `proxmox_endpoint`*
- **[P0]** Create an **API token** for an automation user; provide `user@realm!tokenid`
  + secret. Roles needed: VM.Allocate, VM.Clone, VM.Config.*, Datastore.AllocateSpace,
  SDN/Network use. — *tfvars `proxmox_api_token`*
- **[P0]** Node name (`pvesh get /nodes`). — *tfvars `proxmox_node`*
- **[P0]** Storage pool for VM disks (e.g. `local-lvm`, `local-zfs`, a Ceph pool).
  Thin-provisioned? — *tfvars `proxmox_storage`*
- **[P0]** SSH access to the Proxmox host (key-based) for the automation user. — *provider ssh / scripts*
- **[P1]** Proxmox version (8.x?) — confirms provider compatibility. — *versions.tf*
- **[P1]** Host capacity: total cores, RAM, free disk? (MVP ≈ 8 vCPU oversubscribed,
  ~18 GB RAM, ~240 GB. Full range ≈ 3–4× that.) — *sizing sanity*
- **[P2]** Terraform **or** OpenTofu preferred? (config supports both.) — *tooling*
- **[P2]** Where should **Terraform state** live — local file, or a shared backend?
  — *state management*

## 2. VM templates  [P0]

> This repo **clones** templates; it doesn't build them. Building them from your ISOs
> is the one-time prerequisite (see BUILD_RUNBOOK.md §0).

- **[P0]** Do cloud-init/**cloudbase-init** templates already exist? For which OSes? — *tfvars `template_ids`*
- **[P0]** Template VM IDs for: **Server 2019**, **Win11 Enterprise**, **Kali**. — *tfvars `template_ids.{win2019,win11,kali}`*
- **[P1]** Do the Windows templates have **WinRM enabled + firewall open (5985)** and
  the **QEMU guest agent** installed? (Ansible needs WinRM; Terraform likes the agent.) — *inv / provider*
- **[P1]** Is the shared local Administrator password set via cloudbase-init and
  retrievable with `qm cloudinit dump <vmid> user`? — *vault `vault_windows_admin_password`*
- **[P2]** (Later) Server 2016 / 2025 template IDs for Stage 3–4 mixed-age hosts. — *tfvars*
- **[P2]** Should I provide a **template-build playbook/script** to automate creating
  the templates too (Packer or a documented manual procedure)? — *scope of automation*

## 3. Networking & isolation  [P0]

- **[P0]** Name of the **isolated Proxmox bridge** for the range (no uplink). Does it
  exist, or should we create it? — *tfvars `proxmox_bridge`*
- **[P0]** Confirm the range subnet + gateway. Default `10.20.10.0/24`, gw
  `10.20.10.1` — keep or change? Any conflict with campus/VPN routes? — *tfvars/all.yml `ip_network`,`gateway`*
- **[P1]** **VLAN tag** required on the bridge? If so, which VLAN ID? — *tfvars (add `vlan_id`)*
- **[P1]** Is there a **management interface** separate from the range bridge (for the
  control host / VPN to reach Proxmox but NOT give VMs an uplink)? — *network design*
- **[P1]** Confirm the range must have **no Internet and no campus reachability**
  (enforced by `common_prereqs` isolation check + `validate.yml`). — *safety*

## 4. IP plan, DNS & naming  [P1]

- **[P1]** Keep proposed IPs (dc1 .10, sql1 .20, ws1 .50, kali .100)? — *all.yml `hosts.*`*
- **[P1]** Keep proposed VM IDs (210/220/250/200)? Any Proxmox VMID ranges reserved? — *tfvars `vms`, scripts VMIDS*
- **[P1]** Confirm domain `buttersfarm.lab` / NetBIOS `BUTTERS` (themed to CPTC12). — *all.yml*
- **[P2]** DNS forwarders? (Normally none — isolated. Confirm no upstream DNS.) — *dc config*

## 5. Secrets & credential management  [P0]

- **[P0]** OK to use **Ansible Vault** for all secrets (recommended), with the vault
  password in `~/.ansible-secrets/larpers_vault_pass`? Or do you use another secret
  store (Bitwarden, 1Password, HashiCorp Vault)? — *ansible.cfg / vault*
- **[P0]** Provide/confirm the 4 lab secrets: local+domain Administrator, DSRM, SQL
  `sa`, AD user default password. (Strong, lab-only, never committed.) — *vault*
- **[P1]** Password policy for the synthetic AD users at Stage 1 (strong) — confirm
  you want Stage 2 to introduce the *intentional* weak ones separately. — *staging*
- **[P1]** Who holds the vault password / how is it shared among coaches? — *ops*

## 6. SQL Server  [P1]

- **[P1]** Confirm you'll use **SQL Server 2019 Developer** (not the Evaluation stub
  you have). Who downloads it and where does it get staged (baked into the sql1
  template, or copied to `C:\Installers\SQL2019-Dev\`)? — *all.yml `mssql_installer_path`*
- **[P1]** Default instance (`MSSQLSERVER`) OK, or a named instance? — *all.yml `mssql_instance_name`*
- **[P2]** One SQL server for MVP (recommended) — confirm; second SQL server is Stage 4. — *staging*

## 7. Identity / theme  [P1 — mostly decided]

- **[P1]** Confirm Butters Family Farm theme values (domain, DB `ParkOps`, park OUs/
  personas). Any changes to fictional names? — *all.yml*
- **[P2]** Number of Win11 endpoints at Stage 3 (2–4) and which personas
  (guest_services / rides_ops / maintenance / finance / it / exec)? — *hosts map*

## 8. Attacker VM (Kali)  [P1]

- **[P1]** Build Kali from your ISO into a template, or adapt the (MIT) AttackerVMs
  automation in the separate `cptc-2026-attacker-vms` repo? — *scope*
- **[P1]** Baseline toolset confirmation (nmap, netexec, impacket, BloodHound,
  Responder, evil-winrm, Rubeus, certipy, etc. — matches your playbook). — *attacker repo*
- **[P2]** One shared Kali, or one per student? Resource impact. — *sizing*

## 9. Snapshots, reset & lifecycle  [P2]

- **[P2]** Confirm the snapshot/reset model (named per-stage snapshots + `qm rollback`).
  Auto-update disabled in templates so snapshots stay stable? — *scripts*
- **[P2]** Do you want a **scheduled nightly reset** to `stageN-clean` (via cron on
  Proxmox)? — *ops automation*

## 10. Repo, access & licensing  [P0 for Stage 2+]

- **[P0 for Stage 2+]** CyberHawks `cyber-range` reuse: explicit written owner
  permission obtained (or LICENSE added)? Until then vuln roles stay stubbed. — *UPSTREAM.md*
- **[P1]** GitHub org/owner for the private repos (`n3t1nv4d3`?) and who gets
  student vs coach access? — *repo setup*
- **[P1]** OK to add the Option-3 auto-build GitHub Action (rebuilds artifacts on push)? — *CI*

## 11. How far to automate?  [P1]

- **[P1]** Target: **one-command build** (`terraform apply && ansible-playbook site.yml`)
  from a connected control host — confirm that's the goal.
- **[P2]** Do you also want the **template build** automated (Packer), or is manual
  template creation acceptable (documented)? — *biggest remaining manual step*
- **[P2]** Any requirement to run builds **unattended/scheduled** (which the VPN's
  interactive auth may block)? — *decides control-host design*

---

### The true critical path (answer these first and I can wire the build)
1. **§0 P0** — can the build host reach Proxmox via GP, or (preferred) without it.
2. **§1 P0** — Proxmox endpoint, API token, node, storage, SSH.
3. **§2 P0** — template IDs (or a "yes, automate template building too").
4. **§3 P0** — isolated bridge name + subnet confirmation.
5. **§5 P0** — vault approach + the 4 secrets.
