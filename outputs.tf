# ─────────────────────────────────────────────────────────────
# vyos-rtr-1 (master)
# ─────────────────────────────────────────────────────────────
output "vyos_rtr_1_vm_id" {
  description = "PVE VM ID of vyos-rtr-1"
  value       = module.vyos_rtr_1.vm_id
}

output "vyos_rtr_1_node" {
  description = "PVE node hosting vyos-rtr-1"
  value       = module.vyos_rtr_1.node_name
}

output "vyos_rtr_1_mac_address" {
  description = "MAC address of vyos-rtr-1 eth0"
  value       = module.vyos_rtr_1.mac_address
}

output "vyos_rtr_1_ipv4_addresses" {
  description = "All IPv4 addresses reported by guest agent"
  value       = module.vyos_rtr_1.ipv4_addresses
}

output "vyos_rtr_1_bootstrap_ip" {
  description = "DHCP-assigned IPv4 on eth0 (vlan1 bootstrap)"
  value       = module.vyos_rtr_1.bootstrap_ip
}

output "vyos_rtr_1_ssh_command" {
  description = "Convenience command to SSH into vyos-rtr-1"
  value       = module.vyos_rtr_1.ssh_command
}

output "vyos_rtr_1_vlan10_ip" {
  value = module.vyos_rtr_1.vlan10_ip
}

output "vyos_rtr_1_vlan20_ip" {
  value = module.vyos_rtr_1.vlan20_ip
}

output "vyos_rtr_1_vlan30_ip" {
  value = module.vyos_rtr_1.vlan30_ip
}

output "vyos_rtr_1_provisioned" {
  value = module.vyos_rtr_1.provisioned
}

# ─────────────────────────────────────────────────────────────
# vyos-rtr-2 (backup)
# ─────────────────────────────────────────────────────────────
output "vyos_rtr_2_vm_id" {
  value = module.vyos_rtr_2.vm_id
}

output "vyos_rtr_2_node" {
  value = module.vyos_rtr_2.node_name
}

output "vyos_rtr_2_bootstrap_ip" {
  value = module.vyos_rtr_2.bootstrap_ip
}

output "vyos_rtr_2_ssh_command" {
  value = module.vyos_rtr_2.ssh_command
}

output "vyos_rtr_2_vlan10_ip" {
  value = module.vyos_rtr_2.vlan10_ip
}

# ─────────────────────────────────────────────────────────────
# VRRP virtual IPs (HA endpoints — K8s 노드의 default GW)
# ─────────────────────────────────────────────────────────────
output "vrrp_vip_vlan10" {
  description = "Virtual IP for vlan10 (mgmt)"
  value       = split("/", var.vrrp_vip_vlan10)[0]
}

output "vrrp_vip_vlan20" {
  description = "Virtual IP for vlan20 (k8s-svc) — K8s nodes' default gateway"
  value       = split("/", var.vrrp_vip_vlan20)[0]
}

output "vrrp_vip_vlan30" {
  description = "Virtual IP for vlan30 (storage)"
  value       = split("/", var.vrrp_vip_vlan30)[0]
}

# ─────────────────────────────────────────────────────────────
# K8s cluster
# ─────────────────────────────────────────────────────────────
output "k8s_control_plane_ips" {
  description = "Control plane 노드 IP 목록"
  value       = module.k8s_cluster.control_plane_ips
}

output "k8s_worker_ips" {
  description = "Worker 노드 IP 목록"
  value       = module.k8s_cluster.worker_ips
}

output "k8s_vip" {
  description = "K8s API server VIP (kube-vip)"
  value       = module.k8s_cluster.k8s_vip
}

output "k8s_kubeconfig_path" {
  description = "로컬에 저장된 kubeconfig 경로"
  value       = module.k8s_cluster.kubeconfig_path
}
