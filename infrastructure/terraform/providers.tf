# Proxmox provider config. Auth via API token (preferred) — set the secret
# through the terraform.tfvars file or the PROXMOX_VE_API_TOKEN env var.
# Never commit the token.

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token # format: "user@realm!tokenid=uuid"
  insecure  = var.proxmox_insecure  # true only for self-signed lab certs

  # SSH is used by the provider for some disk/clone operations.
  ssh {
    agent    = true
    username = var.proxmox_ssh_user
  }
}
