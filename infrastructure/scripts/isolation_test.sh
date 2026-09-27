#!/usr/bin/env bash
# Quick host-side sanity check that the range bridge has no uplink.
# Run ON the Proxmox host. This checks the bridge config; the Ansible
# common_prereqs role also checks from *inside* each VM (the real test).
set -euo pipefail

BRIDGE="${1:-vmbr-range}"

echo "[*] Inspecting bridge: $BRIDGE"
if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
  echo "[!] Bridge $BRIDGE does not exist yet. Create it as an isolated bridge (no bridge-ports / no uplink)."
  exit 1
fi

echo "[*] Bridge members (should be VM taps only, NO physical NIC like enpXsY/eno1):"
bridge link | grep "master $BRIDGE" || echo "  (none yet)"

echo
echo "[i] The authoritative test runs from inside the VMs:"
echo "    ansible-playbook validate.yml   # asserts each VM canNOT reach 1.1.1.1:443"
echo "[i] If any physical NIC is a member of $BRIDGE, the range is NOT isolated — remove it."
