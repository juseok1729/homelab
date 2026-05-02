# Phase1
output "vyos_rtr_1_vm_id" {
  description = "PVE VM ID of vyos-rtr-1"
  value       = proxmox_virtual_environment_vm.vyos_rtr_1.vm_id
}

output "vyos_rtr_1_node" {
  description = "PVE node hosting vyos-rtr-1"
  value       = proxmox_virtual_environment_vm.vyos_rtr_1.node_name
}

output "vyos_rtr_1_mac_address" {
  description = "MAC address of vyos-rtr-1 eth0"
  value       = try(proxmox_virtual_environment_vm.vyos_rtr_1.mac_addresses[1], "unknown")
}

output "vyos_rtr_1_ipv4_addresses" {
  description = "All IPv4 addresses reported by guest agent"
  value       = proxmox_virtual_environment_vm.vyos_rtr_1.ipv4_addresses
}

output "vyos_rtr_1_bootstrap_ip" {
  description = "DHCP-assigned IPv4 on eth0 (vlan1 bootstrap)"
  # ipv4_addresses는 [["127.0.0.1"], ["192.168.219.X"], ...] 형태
  # 첫 인터페이스(lo) 제외하고 두 번째(eth0) 선택
  value = try(
    [for ip in proxmox_virtual_environment_vm.vyos_rtr_1.ipv4_addresses[1] : ip if !startswith(ip, "169.254")][0],
    "agent not ready"
  )
}

output "vyos_rtr_1_ssh_command" {
  description = "Convenience command to SSH into vyos-rtr-1"
  value = "ssh ${var.vyos_default_user}@${try(
    [for ip in proxmox_virtual_environment_vm.vyos_rtr_1.ipv4_addresses[1] : ip if !startswith(ip, "169.254")][0],
    "<unknown>"
  )}"
}

# Phase2
output "vyos_rtr_1_vlan10_ip" {
  value = trimsuffix(var.vyos_rtr_1_vlan10_ip, "/24")
}

output "vyos_rtr_1_vlan20_ip" {
  value = trimsuffix(var.vyos_rtr_1_vlan20_ip, "/24")
}

output "vyos_rtr_1_vlan30_ip" {
  value = trimsuffix(var.vyos_rtr_1_vlan30_ip, "/24")
}

output "vyos_rtr_1_provisioned" {
  value      = "vyos-rtr-1 production config applied (config_version: ${var.vyos_rtr_1_config_version})"
  depends_on = [null_resource.vyos_rtr_1_provision]
}
