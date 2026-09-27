# Build Runbook — The Larpers CPTC Range (MVP)

End-to-end steps to stand up the Stage-1 range. ~an afternoon the first time.

## 0. Prerequisites (one-time)

**Control host** (your workstation or a small Linux box):
- `terraform` ≥ 1.6 (or `tofu`), `ansible` ≥ 2.16, `python3` with `pywinrm`.
- `ansible-galaxy collection install -r ansible/requirements.yml`
- Network path to Proxmox for the build host. **Preferred: reach Proxmox WITHOUT
  GlobalProtect** (lab LAN), since GP's SSO/MFA makes unattended connects hard. Use
  **GlobalProtect for student range access** (GP → management net → range). If the
  build host must go over GP, connect the GP GUI first, then run the commands below.

**Proxmox templates** (this repo clones them; it does not build them):
1. Create VMs from your ISOs (Server 2019, Win11 Enterprise, Kali).
2. Install **QEMU guest agent** and, on Windows, **cloudbase-init** (so Terraform
   can push hostname/IP/credentials). On Linux/Kali, cloud-init.
3. Generalize (Windows: `sysprep /generalize /oobe`; leave cloudbase-init to run
   on first boot) and convert each to a **template**.
4. Note each template's VM ID → put in `terraform.tfvars` `template_ids`.

**Isolation**: create an isolated Proxmox bridge (e.g. `vmbr-range`) with **no
physical NIC / no uplink**. Verify with `scripts/isolation_test.sh vmbr-range`.

## 1. Configure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
$EDITOR terraform/terraform.tfvars          # endpoint, token, node, storage, bridge, template_ids
$EDITOR ansible/group_vars/all.yml          # domain, subnet, company, hosts, vuln_stage=1
cp ansible/group_vars/vault.example.yml ansible/group_vars/vault.yml
$EDITOR ansible/group_vars/vault.yml        # set the 4 secrets
ansible-vault encrypt ansible/group_vars/vault.yml
echo 'YOUR-VAULT-PASSWORD' > ~/.ansible-secrets/larpers_vault_pass && chmod 600 ~/.ansible-secrets/larpers_vault_pass
```

Place the **SQL Server 2019 Developer** installer where `mssql_installer_path`
points (default `C:\Installers\SQL2019-Dev\setup.exe` on sql1 — bake it into the
template, or copy it up before the SQL role runs).

## 2. Provision (Terraform)

```bash
cd terraform
terraform init
terraform plan      # review: 4 VMs cloned, static IPs, isolated bridge
terraform apply
cd ..
```
Confirm the 4 VMs booted and got their IPs (`terraform output range_vms`).

## 3. Configure (Ansible)

```bash
cd ansible
ansible -m ansible.windows.win_ping all      # all Windows hosts should respond
ansible-playbook site.yml                    # promote DC, build AD, install SQL, seed data, join ws1
```
Re-running `site.yml` is safe (idempotent).

## 4. Validate

```bash
ansible-playbook validate.yml
```
Expect: dcdiag OK, AD users present, non-admin shares listed, business DB tables
+ employees counted, ws1 joined, and **every VM isolated** (no Internet).

## 5. Snapshot (known-good)

```bash
# on the Proxmox host:
./scripts/snapshot.sh stage1-clean
```
Reset anytime with `./scripts/reset.sh stage1-clean`.

## 6. First exercises

Run the beginner exercises from the design review (scope read-through, asset
discovery, AD enumeration write-up, evidence-discipline drill) against this MVP.
No exploits are enabled yet — that's intentional.

---

## Troubleshooting

- **WinRM unreachable**: confirm the template enabled WinRM + firewall; the control
  host's `pywinrm` is installed; NTLM transport; port 5985 open on the range bridge.
- **DC promotion loops/reboots**: expected once; the play waits for ADWS after.
- **SQL install fails**: you likely have the Evaluation stub — use **Developer**
  (REQUIRED_INPUTS.md E1). Check `%programfiles%\Microsoft SQL Server\...\Setup Bootstrap\Log\Summary.txt`.
- **A VM can reach the Internet**: a physical NIC is on the range bridge — remove it.
  Do not proceed until `validate.yml` reports ISOLATED.
- **Server 2016 hosts hang on shutdown before snapshot**: let Windows Update finish;
  disable auto-update in the template.

## Growing past MVP

Add hosts to `terraform.tfvars` `vms` and `ansible/inventory/hosts.yml`, raise
`vuln_stage`, and wire the (permission-gated) roles in `roles/_vuln_stubs/` into
`site.yml`. Keep one finding per host where possible (the reference design's rule)
and snapshot a new `stageN-clean` each time.
