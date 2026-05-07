# ─────────────────────────────────────────────────────────────
# Control plane VMs
# ─────────────────────────────────────────────────────────────
module "cp" {
  for_each = { for cp in local.control_planes : cp.name => cp }
  source   = "./k8s-vm"

  vm_id         = each.value.vm_id
  name          = each.value.name
  node_name     = each.value.node
  template_id   = var.ubuntu_template_id
  template_node = each.value.node == var.template_node ? null : var.template_node
  description   = "K8s control plane — managed by Terraform"
  tags          = local.tags_cp

  cores     = var.cp_cores
  memory    = var.cp_memory
  disk_size = var.cp_disk_size
  datastore = var.datastore

  ip_address     = each.value.ip
  gateway        = var.gateway
  dns_servers    = var.dns_servers
  ssh_public_key = var.ssh_public_key
}

# ─────────────────────────────────────────────────────────────
# Worker VMs
# ─────────────────────────────────────────────────────────────
module "worker" {
  for_each = { for w in local.workers : w.name => w }
  source   = "./k8s-vm"

  vm_id         = each.value.vm_id
  name          = each.value.name
  node_name     = each.value.node
  template_id   = var.ubuntu_template_id
  template_node = each.value.node == var.template_node ? null : var.template_node
  description   = "K8s worker — managed by Terraform"
  tags          = local.tags_worker

  cores     = each.value.cores
  memory    = each.value.memory
  disk_size = each.value.disk_size
  datastore = var.datastore

  ip_address     = each.value.ip
  gateway        = var.gateway
  dns_servers    = var.dns_servers
  ssh_public_key = var.ssh_public_key
}

# ─────────────────────────────────────────────────────────────
# K8s bootstrap (Ansible) — VM 생성 완료 후 실행
# ─────────────────────────────────────────────────────────────
module "bootstrap" {
  source = "./k8s-bootstrap"

  depends_on = [module.cp, module.worker]

  control_planes = local.cp_bootstrap
  workers        = local.worker_bootstrap

  ssh_private_key_path   = var.ssh_private_key_path
  kubeconfig_output_path = var.kubeconfig_output_path
  bootstrap_trigger      = var.bootstrap_trigger

  k8s_vip      = var.k8s_vip
  pod_cidr     = var.pod_cidr
  service_cidr = var.service_cidr
  k8s_bgp_as   = var.k8s_bgp_as
  vyos_bgp_as  = var.vyos_bgp_as
  vyos_vip     = var.vyos_vip
}
