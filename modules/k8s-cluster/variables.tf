# ─────────────────────────────────────────────────────────────
# Template
# ─────────────────────────────────────────────────────────────
variable "ubuntu_template_id" {
  description = "Ubuntu template VM ID (Packer로 빌드한 9001)"
  type        = number
  default     = 9001
}

variable "template_node" {
  description = "Ubuntu 템플릿이 있는 PVE 노드"
  type        = string
  default     = "pve-node1"
}

variable "datastore" {
  type    = string
  default = "local-lvm"
}

# ─────────────────────────────────────────────────────────────
# Control plane VM specs
# ─────────────────────────────────────────────────────────────
variable "cp_cores" {
  type    = number
  default = 2
}

variable "cp_memory" {
  description = "Control plane memory in MB"
  type        = number
  default     = 4096
}

variable "cp_disk_size" {
  description = "Control plane disk in GB"
  type        = number
  default     = 30
}

# ─────────────────────────────────────────────────────────────
# Network
# ─────────────────────────────────────────────────────────────
variable "gateway" {
  description = "vlan20 기본 게이트웨이 (VyOS VRRP VIP)"
  type        = string
  default     = "192.168.20.1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["192.168.20.1", "8.8.8.8"]
}

# ─────────────────────────────────────────────────────────────
# Kubernetes
# ─────────────────────────────────────────────────────────────
variable "k8s_vip" {
  description = "kube-vip API server VIP (vlan20)"
  type        = string
  default     = "192.168.20.10"
}

variable "pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}

variable "k8s_bgp_as" {
  type    = number
  default = 65001
}

variable "vyos_bgp_as" {
  type    = number
  default = 65000
}

variable "vyos_vip" {
  description = "VyOS VRRP VIP on vlan20 — Cilium BGP peer"
  type        = string
  default     = "192.168.20.1"
}

# ─────────────────────────────────────────────────────────────
# SSH
# ─────────────────────────────────────────────────────────────
variable "ssh_public_key" {
  description = "cloud-init으로 주입할 SSH 공개키"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Ansible이 사용할 SSH 개인키 경로"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "kubeconfig_output_path" {
  description = "kubeconfig를 저장할 로컬 경로"
  type        = string
  default     = "~/.kube/homelab-config"
}

variable "bootstrap_trigger" {
  description = "재부트스트랩을 트리거하기 위해 bump"
  type        = string
  default     = "v1"
}
