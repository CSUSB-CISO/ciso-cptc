#!/usr/bin/env bash
# Named snapshot of all range VMs. Run ON the Proxmox host (or via SSH).
#   ./snapshot.sh stage1-clean
set -euo pipefail

SNAP="${1:?usage: snapshot.sh <snapshot-name>}"
# VM IDs must match terraform/terraform.tfvars (var.vms[*].vmid).
VMIDS=(210 220 250 200)   # dc1 sql1 ws1 kali

for id in "${VMIDS[@]}"; do
  echo "[*] Snapshotting VM $id -> $SNAP"
  qm snapshot "$id" "$SNAP" --description "Larpers range snapshot: $SNAP ($(date -u +%FT%TZ))" || {
    echo "[!] snapshot failed for $id (is it a clean/stopped state?)"; exit 1; }
done
echo "[+] All snapshots '$SNAP' created."
