# ── Proxmox connection ───────────────────────────────────────────────────────
variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://192.168.192.150:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token: user@realm!tokenid=secret. Keep in tfvars/env, never commit."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (self-signed lab cert only)."
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user on the Proxmox host (for clone/disk ops)."
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Proxmox node name to build on, e.g. pve."
  type        = string
}

variable "proxmox_storage" {
  description = "Storage pool for VM disks, e.g. local-lvm."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_bridge" {
  description = "[PROPOSAL] Isolated bridge for the range (no uplink)."
  type        = string
  default     = "vmbr-range"
}

# ── Range network ────────────────────────────────────────────────────────────
variable "ip_cidr_bits" {
  description = "CIDR prefix length for the range subnet."
  type        = number
  default     = 24
}

variable "gateway" {
  description = "[PROPOSAL] Range gateway (or empty string for fully isolated)."
  type        = string
  default     = "10.20.10.1"
}

variable "dns_server" {
  description = "DNS for range VMs — should be dc1's IP once promoted."
  type        = string
  default     = "10.20.10.10"
}

# ── Template IDs (build these once on Proxmox; see REQUIRED_INPUTS.md) ────────
variable "template_ids" {
  description = "Map of OS key -> Proxmox template VM ID to clone from."
  type        = map(number)
  # EXAMPLES — replace with your real template IDs in terraform.tfvars
  default = {
    win2019 = 9019
    win11   = 9011
    kali    = 9200
    # win2016 = 9016   # Stage 3-4
    # win2025 = 9025   # Stage 4
  }
}

# ── The VMs to build. MVP = 4. Add rows to grow the range. ───────────────────
variable "vms" {
  description = "Map of VM name -> spec. Clone source is template_ids[template]."
  type = map(object({
    vmid     = number
    template = string # key into template_ids
    cores    = number
    memory   = number # MB
    disk_gb  = number
    ip       = string # last octet or full IP; full IP used here
    tags     = optional(list(string), [])
  }))

  default = {
    dc1 = {
      vmid = 210, template = "win2019", cores = 2, memory = 4096, disk_gb = 60,
      ip = "10.20.10.10", tags = ["larpers", "stage1", "dc"]
    }
    sql1 = {
      vmid = 220, template = "win2019", cores = 2, memory = 6144, disk_gb = 80,
      ip = "10.20.10.20", tags = ["larpers", "stage1", "sql"]
    }
    ws1 = {
      vmid = 250, template = "win11", cores = 2, memory = 4096, disk_gb = 60,
      ip = "10.20.10.50", tags = ["larpers", "stage1", "workstation"]
    }
    kali = {
      vmid = 200, template = "kali", cores = 2, memory = 4096, disk_gb = 40,
      ip = "10.20.10.100", tags = ["larpers", "attacker"]
    }
  }
}

variable "vm_username" {
  description = "Initial admin/cloud-init username baked into templates."
  type        = string
  default     = "Administrator"
}

variable "vm_password" {
  description = "Initial admin password (cloud-init/cloudbase-init). Lab-only; keep out of VCS."
  type        = string
  sensitive   = true
}

variable "team_name" {
  description = "Branding tag."
  type        = string
  default     = "The Larpers"
}
