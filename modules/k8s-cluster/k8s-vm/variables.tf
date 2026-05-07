# ─────────────────────────────────────────────────────────────
# Proxmox placement
# ─────────────────────────────────────────────────────────────
variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
}

variable "name" {
  description = "VM 이름 및 hostname"
  type        = string
}

variable "node_name" {
  description = "배포할 PVE 노드"
  type        = string
}

variable "template_id" {
  description = "Ubuntu 템플릿 VM ID"
  type        = number
}

variable "template_node" {
  description = "템플릿이 있는 PVE 노드 (cross-node clone 시 지정)"
  type        = string
  default     = null
}

variable "description" {
  type    = string
  default = ""
}

variable "tags" {
  type    = list(string)
  default = []
}

# ─────────────────────────────────────────────────────────────
# VM sizing
# ─────────────────────────────────────────────────────────────
variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 30
}

variable "datastore" {
  type    = string
  default = "local-lvm"
}

# ─────────────────────────────────────────────────────────────
# Network (vlan20 — k8s-svc)
# ─────────────────────────────────────────────────────────────
variable "ip_address" {
  description = "CIDR 형식 정적 IP, 예: 192.168.20.11/24"
  type        = string
}

variable "gateway" {
  description = "기본 게이트웨이 (VyOS VRRP VIP)"
  type        = string
  default     = "192.168.20.1"
}

variable "dns_servers" {
  description = "DNS 서버 목록"
  type        = list(string)
  default     = ["192.168.20.1", "8.8.8.8"]
}

# ─────────────────────────────────────────────────────────────
# Cloud-init credentials
# ─────────────────────────────────────────────────────────────
variable "ssh_public_key" {
  description = "cloud-init으로 주입할 SSH 공개키"
  type        = string
}
