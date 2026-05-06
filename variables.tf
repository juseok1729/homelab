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
