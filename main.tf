# ─────────────────────────────────────────────────────────────
# VyOS HA Router Pair (VRRP master + backup)
# ─────────────────────────────────────────────────────────────

module "vyos_rtr_1" {
  source = "./modules/vyos-router"

  vm_id       = var.vyos_rtr_1_vm_id
  name        = var.vyos_rtr_1_name
  node_name   = var.pve_node_name
  template_id = var.vyos_template_id
  # template_node omitted — template and VM are on the same node (pve-node1)
  description = "VyOS HA router (master) - managed by Terraform"
  tags        = local.vm_tags_router

  cores     = var.vyos_rtr_1_cores
  memory    = var.vyos_rtr_1_memory
  disk_size = var.vyos_rtr_1_disk_size
  datastore = local.datastore

  config_version = var.vyos_rtr_1_config_version
  role           = "master"

  vlan10_ip = var.vyos_rtr_1_vlan10_ip
  vlan20_ip = var.vyos_rtr_1_vlan20_ip
  vlan30_ip = var.vyos_rtr_1_vlan30_ip

  vrrp_vip_vlan10         = var.vrrp_vip_vlan10
  vrrp_vip_vlan20         = var.vrrp_vip_vlan20
  vrrp_vip_vlan30         = var.vrrp_vip_vlan30
  vrrp_priority_master    = var.vrrp_priority_master
  vrrp_priority_backup    = var.vrrp_priority_backup
  vrrp_advertise_interval = var.vrrp_advertise_interval

  default_user     = var.vyos_default_user
  default_password = var.vyos_default_password

  bgp_enabled   = var.vyos_bgp_enabled
  bgp_local_as  = 65000
  bgp_neighbors = var.vyos_bgp_enabled ? local.k8s_bgp_neighbors : []
}

module "vyos_rtr_2" {
  source = "./modules/vyos-router"

  vm_id         = var.vyos_rtr_2_vm_id
  name          = var.vyos_rtr_2_name
  node_name     = var.vyos_rtr_2_node
  template_id   = var.vyos_template_id
  template_node = var.pve_node_name # template lives on pve-node1
  description   = "VyOS HA router (backup) - managed by Terraform"
  tags          = local.vm_tags_router

  cores     = var.vyos_rtr_2_cores
  memory    = var.vyos_rtr_2_memory
  disk_size = var.vyos_rtr_2_disk_size
  datastore = local.datastore

  config_version = var.vyos_rtr_2_config_version
  role           = "backup"

  vlan10_ip = var.vyos_rtr_2_vlan10_ip
  vlan20_ip = var.vyos_rtr_2_vlan20_ip
  vlan30_ip = var.vyos_rtr_2_vlan30_ip

  vrrp_vip_vlan10         = var.vrrp_vip_vlan10
  vrrp_vip_vlan20         = var.vrrp_vip_vlan20
  vrrp_vip_vlan30         = var.vrrp_vip_vlan30
  vrrp_priority_master    = var.vrrp_priority_master
  vrrp_priority_backup    = var.vrrp_priority_backup
  vrrp_advertise_interval = var.vrrp_advertise_interval

  default_user     = var.vyos_default_user
  default_password = var.vyos_default_password

  bgp_enabled   = var.vyos_bgp_enabled
  bgp_local_as  = 65000
  bgp_neighbors = var.vyos_bgp_enabled ? local.k8s_bgp_neighbors : []
}

# ─────────────────────────────────────────────────────────────
# K8s HA Cluster (3 CP + 3 Worker)
# Ubuntu 템플릿(9001)에서 clone → kubeadm + kube-vip + Cilium BGP
# ─────────────────────────────────────────────────────────────
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

  ubuntu_template_id = var.ubuntu_template_id
  template_node      = var.pve_node_name
  datastore          = local.datastore

  cp_cores     = var.k8s_cp_cores
  cp_memory    = var.k8s_cp_memory
  cp_disk_size = var.k8s_cp_disk_size

  gateway     = split("/", var.vrrp_vip_vlan20)[0]
  dns_servers = [split("/", var.vrrp_vip_vlan20)[0], "8.8.8.8"]

  k8s_vip      = var.k8s_vip
  pod_cidr     = var.k8s_pod_cidr
  service_cidr = var.k8s_service_cidr
  k8s_bgp_as   = 65001
  vyos_bgp_as  = 65000
  vyos_vip     = split("/", var.vrrp_vip_vlan20)[0]

  ssh_public_key         = var.k8s_ssh_public_key
  ssh_private_key_path   = var.k8s_ssh_private_key_path
  kubeconfig_output_path = var.k8s_kubeconfig_output_path
  bootstrap_trigger      = var.k8s_bootstrap_trigger
}
