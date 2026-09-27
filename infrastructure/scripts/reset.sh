#!/usr/bin/env bash
# Roll all range VMs back to a named snapshot. Run ON the Proxmox host.
#   ./reset.sh stage1-clean
set -euo pipefail

SNAP="${1:?usage: reset.sh <snapshot-name>}"
VMIDS=(210 220 250 200)   # dc1 sql1 ws1 kali  (match terraform tfvars)

read -r -p "Roll back VMs ${VMIDS[*]} to snapshot '$SNAP'? This discards current state. [y/N] " ok
[[ "${ok,,}" == "y" ]] || { echo "aborted"; exit 1; }

for id in "${VMIDS[@]}"; do
  echo "[*] Rolling VM $id back to $SNAP"
  qm rollback "$id" "$SNAP"
  qm start "$id" || true
done
echo "[+] Rollback to '$SNAP' complete. Re-run ansible-playbook validate.yml to confirm."
