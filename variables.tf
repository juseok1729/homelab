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
