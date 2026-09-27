output "range_vms" {
  description = "name -> {vmid, ip} for the built VMs (feed into Ansible inventory)."
  value = {
    for name, vm in var.vms : name => {
      vmid = vm.vmid
      ip   = vm.ip
    }
  }
}

output "ansible_hint" {
  description = "Reminder of the next step."
  value       = "Update ansible/group_vars/all.yml IPs if changed, then: ansible-playbook site.yml"
}
