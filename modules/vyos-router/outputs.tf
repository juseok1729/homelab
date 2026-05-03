output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "node_name" {
  value = proxmox_virtual_environment_vm.this.node_name
}

output "mac_address" {
  value = try(proxmox_virtual_environment_vm.this.mac_addresses[1], "unknown")
}

output "ipv4_addresses" {
  value = proxmox_virtual_environment_vm.this.ipv4_addresses
}

output "bootstrap_ip" {
  value = local.bootstrap_ip
}

output "ssh_command" {
  value = "ssh ${var.default_user}@${local.bootstrap_ip}"
}

output "vlan10_ip" {
  value = split("/", var.vlan10_ip)[0]
}

output "vlan20_ip" {
  value = split("/", var.vlan20_ip)[0]
}

output "vlan30_ip" {
  value = split("/", var.vlan30_ip)[0]
}

output "provisioned" {
  description = "Confirms provisioning completed for this router"
  value       = "config applied (version: ${var.config_version}, role: ${var.role})"
  depends_on  = [null_resource.provision]
}
