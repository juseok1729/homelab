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

# ─────────────────────────────────────────────────────────────
# Tailscale Gateway (LXC subnet router)
# 외부에서 Tailscale VPN으로 내부 VLAN + 관리 네트워크 접근
# ─────────────────────────────────────────────────────────────
resource "proxmox_virtual_environment_download_file" "debian_lxc_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.pve_node_name
  url          = "http://download.proxmox.com/images/system/debian-12-standard_12.12-1_amd64.tar.zst"
  overwrite    = false
}

module "tailscale_gw" {
  source = "./modules/lxc-container"

  ct_id            = var.tailscale_gw_ct_id
  name             = "tailscale-gw"
  node_name        = var.pve_node_name
  template_file_id = proxmox_virtual_environment_download_file.debian_lxc_template.id
  description      = "Tailscale subnet router - managed by Terraform"
  tags             = local.vm_tags_gw

  datastore  = local.datastore
  vlan_id    = 10
  ip_address = var.tailscale_gw_ip
  gateway    = split("/", var.vrrp_vip_vlan10)[0]

  ssh_public_keys = [var.k8s_ssh_public_key]

  # 주의: device_passthrough는 root@pam 전용이라 API 토큰(terraform@pve)으로는 불가.
  # /dev/net/tun은 아래 프로비저닝에서 pct set --dev0로 부착한다.
}

# tailscale 설치 + subnet router 활성화
# auth key가 설정된 경우에만 실행 — pve-node1에 SSH 접속 후 pct exec로 컨테이너 내부 실행
resource "null_resource" "tailscale_gw_provision" {
  count = var.tailscale_auth_key != "" ? 1 : 0

  triggers = {
    config_version = var.tailscale_gw_config_version
    ct_id          = module.tailscale_gw.ct_id
  }

  connection {
    type        = "ssh"
    host        = local.pve_node1_ip
    user        = "root"
    private_key = file(pathexpand(var.k8s_ssh_private_key_path))
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      # tun 디바이스 부착 (없을 때만 설정 + 재시작 후 기동 대기)
      "pct exec ${module.tailscale_gw.ct_id} -- test -c /dev/net/tun || { pct set ${module.tailscale_gw.ct_id} --dev0 path=/dev/net/tun && pct reboot ${module.tailscale_gw.ct_id}; }",
      "for i in $(seq 1 30); do pct exec ${module.tailscale_gw.ct_id} -- test -c /dev/net/tun 2>/dev/null && break; sleep 2; done",
      "pct exec ${module.tailscale_gw.ct_id} -- sh -c 'command -v tailscale >/dev/null || (apt-get update -qq && apt-get install -y -qq curl ca-certificates && curl -fsSL https://tailscale.com/install.sh | sh)'",
      "pct exec ${module.tailscale_gw.ct_id} -- sh -c 'printf \"net.ipv4.ip_forward=1\\nnet.ipv6.conf.all.forwarding=1\\n\" > /etc/sysctl.d/99-tailscale.conf && sysctl -q -p /etc/sysctl.d/99-tailscale.conf'",
      "pct exec ${module.tailscale_gw.ct_id} -- tailscale up --auth-key='${var.tailscale_auth_key}' --advertise-routes='${join(",", var.tailscale_advertise_routes)}' --accept-dns=false",
    ]
  }
}
