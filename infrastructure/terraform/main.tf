# Clone each VM in var.vms from its template and set a static IP via
# cloud-init / cloudbase-init. Windows templates must have cloudbase-init
# installed (see docs/BUILD_RUNBOOK.md — template build is a prerequisite).

resource "proxmox_virtual_environment_vm" "range" {
  for_each = var.vms

  name      = each.key
  vm_id     = each.value.vmid
  node_name = var.proxmox_node
  tags      = each.value.tags

  clone {
    vm_id = var.template_ids[each.value.template]
    full  = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = each.value.disk_gb
  }

  network_device {
    bridge = var.proxmox_bridge
    model  = "virtio"
  }

  # Static IP via the provider's cloud-init integration. cloudbase-init on the
  # Windows templates consumes the same config drive.
  initialization {
    dns {
      servers = [var.dns_server]
    }
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.ip_cidr_bits}"
        gateway = var.gateway != "" ? var.gateway : null
      }
    }
    user_account {
      username = var.vm_username
      password = var.vm_password
    }
  }

  lifecycle {
    ignore_changes = [
      # Avoid churn on fields Proxmox/cloudbase-init may normalize.
      initialization[0].user_account,
      disk[0].file_format,
    ]
  }
}
