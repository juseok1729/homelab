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
  tags          = local.vm_tags_router

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
}
