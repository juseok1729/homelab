output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "node_name" {
  value = proxmox_virtual_environment_vm.this.node_name
}

output "ip_address" {
  description = "CIDR에서 순수 IP만 추출"
  value       = split("/", var.ip_address)[0]
}

output "name" {
  value = proxmox_virtual_environment_vm.this.name
}
