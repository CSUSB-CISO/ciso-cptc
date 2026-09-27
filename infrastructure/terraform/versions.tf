terraform {
  required_version = ">= 1.6.0" # works with OpenTofu >= 1.6 as well

  required_providers {
    proxmox = {
      # Actively maintained Proxmox provider.
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}
