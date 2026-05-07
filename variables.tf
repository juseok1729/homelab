# ─────────────────────────────────────────────────────────────
# Proxmox connection
# ─────────────────────────────────────────────────────────────
variable "pve_endpoint" {
  description = "Proxmox VE API endpoint (entry node)"
  type        = string
  default     = "https://192.168.219.11:8006/"
}

variable "pve_api_token" {
  description = "PVE API token in 'user@realm!tokenid=secret' format"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────
# VM placement
# ─────────────────────────────────────────────────────────────
variable "pve_node_name" {
  description = "PVE node name where vyos-rtr-1 will be deployed"
  type        = string
  default     = "pve-node1"
}

variable "vyos_template_id" {
  description = "VM ID of the VyOS template to clone from"
  type        = number
  default     = 9000
}

# ─────────────────────────────────────────────────────────────
# vyos-rtr-1 spec
# ─────────────────────────────────────────────────────────────
variable "vyos_rtr_1_vm_id" {
  type    = number
  default = 110
}

variable "vyos_rtr_1_name" {
  type    = string
  default = "vyos-rtr-1"
}

variable "vyos_rtr_1_cores" {
  type    = number
  default = 2
}

variable "vyos_rtr_1_memory" {
  type    = number
  default = 2048
}

variable "vyos_rtr_1_disk_size" {
  type    = number
  default = 10 # GB
}

# ─────────────────────────────────────────────────────────────
# VyOS template credentials (bootstrap)
# ─────────────────────────────────────────────────────────────
variable "vyos_default_user" {
  type    = string
  default = "vyos"
}

variable "vyos_default_password" {
  description = "Bootstrap password baked into template (will be changed in Phase 3)"
  type        = string
  default     = "vyos"
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────
# vyos-rtr-1 production config
# ─────────────────────────────────────────────────────────────
variable "vyos_rtr_1_vlan10_ip" {
  type    = string
  default = "192.168.10.252/24"
}

variable "vyos_rtr_1_vlan20_ip" {
  type    = string
  default = "192.168.20.252/24"
}

variable "vyos_rtr_1_vlan30_ip" {
  type    = string
  default = "192.168.30.252/24"
}

variable "upstream_gateway" {
  description = "Upstream gateway for default route (ISP router)"
  type        = string
  default     = "192.168.219.1"
}

# ─────────────────────────────────────────────────────────────
# Provisioning trigger
# ─────────────────────────────────────────────────────────────
variable "vyos_rtr_1_config_version" {
  description = "Bump this to re-run provisioning"
  type        = string
  default     = "v1"
}

# ─────────────────────────────────────────────────────────────
# vyos-rtr-2 spec
# ─────────────────────────────────────────────────────────────
variable "vyos_rtr_2_vm_id" {
  type    = number
  default = 120
}

variable "vyos_rtr_2_name" {
  type    = string
  default = "vyos-rtr-2"
}

variable "vyos_rtr_2_node" {
  type    = string
  default = "pve-node2"
}

variable "vyos_rtr_2_cores" {
  type    = number
  default = 2
}

variable "vyos_rtr_2_memory" {
  type    = number
  default = 2048
}

variable "vyos_rtr_2_disk_size" {
  type    = number
  default = 10
}

variable "vyos_rtr_2_vlan10_ip" {
  type    = string
  default = "192.168.10.253/24"
}

variable "vyos_rtr_2_vlan20_ip" {
  type    = string
  default = "192.168.20.253/24"
}

variable "vyos_rtr_2_vlan30_ip" {
  type    = string
  default = "192.168.30.253/24"
}

variable "vyos_rtr_2_config_version" {
  type    = string
  default = "v1"
}

# ─────────────────────────────────────────────────────────────
# VRRP - common across both routers
# ─────────────────────────────────────────────────────────────
variable "vrrp_vip_vlan10" {
  type    = string
  default = "192.168.10.1/24"
}

variable "vrrp_vip_vlan20" {
  type    = string
  default = "192.168.20.1/24"
}

variable "vrrp_vip_vlan30" {
  type    = string
  default = "192.168.30.1/24"
}

variable "vrrp_priority_master" {
  type    = number
  default = 200
}

variable "vrrp_priority_backup" {
  type    = number
  default = 100
}

variable "vrrp_advertise_interval" {
  description = "VRRP advertisement interval in seconds"
  type        = number
  default     = 1
}

# ─────────────────────────────────────────────────────────────
# VyOS BGP (k8s Cilium peering — k8s 구축 후 true로 변경)
# true로 변경 시 config_version도 함께 bump해야 재적용됨
# ─────────────────────────────────────────────────────────────
variable "vyos_bgp_enabled" {
  description = "VyOS BGP 활성화 여부 (Cilium BGP peering)"
  type        = bool
  default     = false
}

# ─────────────────────────────────────────────────────────────
# Ubuntu template
# ─────────────────────────────────────────────────────────────
variable "ubuntu_template_id" {
  description = "Ubuntu 24.04 템플릿 VM ID (packer/ubuntu-template으로 빌드)"
  type        = number
  default     = 9001
}

# ─────────────────────────────────────────────────────────────
# K8s cluster
# ─────────────────────────────────────────────────────────────
variable "k8s_cp_cores" {
  type    = number
  default = 2
}

variable "k8s_cp_memory" {
  description = "Control plane memory in MB"
  type        = number
  default     = 4096
}

variable "k8s_cp_disk_size" {
  description = "Control plane disk in GB"
  type        = number
  default     = 30
}

variable "k8s_vip" {
  description = "kube-vip API server VIP (vlan20)"
  type        = string
  default     = "192.168.20.10"
}

variable "k8s_pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "k8s_service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}

variable "k8s_ssh_public_key" {
  description = "k8s 노드 cloud-init으로 주입할 SSH 공개키 (예: file(\"~/.ssh/id_ed25519.pub\"))"
  type        = string
}

variable "k8s_ssh_private_key_path" {
  description = "Ansible SSH 접속용 개인키 경로"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "k8s_kubeconfig_output_path" {
  description = "kubeconfig를 저장할 로컬 경로"
  type        = string
  default     = "~/.kube/homelab-config"
}

variable "k8s_bootstrap_trigger" {
  description = "재부트스트랩 트리거 (bump하면 Ansible 재실행)"
  type        = string
  default     = "v1"
}
