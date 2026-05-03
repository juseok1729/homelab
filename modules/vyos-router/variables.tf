# ─────────────────────────────────────────────────────────────
# Proxmox placement
# ─────────────────────────────────────────────────────────────
variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
}

variable "name" {
  description = "VM display name and VyOS hostname"
  type        = string
}

variable "node_name" {
  description = "PVE node to deploy the VM on"
  type        = string
}

variable "template_id" {
  description = "VM ID of the VyOS template to clone from"
  type        = number
}

variable "template_node" {
  description = "PVE node where the template resides. Set only for cross-node clones; omit when template and VM share the same node."
  type        = string
  default     = null
}

variable "description" {
  description = "VM description shown in PVE UI"
  type        = string
  default     = ""
}

variable "tags" {
  description = "PVE tags for the VM"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────
# VM sizing
# ─────────────────────────────────────────────────────────────
variable "cores" {
  type    = number
  default = 1
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 1024
}

variable "disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 10
}

variable "datastore" {
  description = "PVE datastore for the VM disk"
  type        = string
  default     = "local-lvm"
}

# ─────────────────────────────────────────────────────────────
# Bootstrap credentials
# ─────────────────────────────────────────────────────────────
variable "default_user" {
  type    = string
  default = "vyos"
}

variable "default_password" {
  type      = string
  sensitive = true
  default   = "vyos"
}

# ─────────────────────────────────────────────────────────────
# Provisioning
# ─────────────────────────────────────────────────────────────
variable "config_version" {
  description = "Bump this string to re-trigger provisioning"
  type        = string
  default     = "v1"
}

# ─────────────────────────────────────────────────────────────
# VRRP role & VLAN IPs
# ─────────────────────────────────────────────────────────────
variable "role" {
  description = "VRRP role for this router instance"
  type        = string
  validation {
    condition     = contains(["master", "backup"], var.role)
    error_message = "role must be 'master' or 'backup'."
  }
}

variable "vlan10_ip" {
  description = "IP/prefix assigned to eth0.10 (mgmt VLAN), e.g. 192.168.10.252/24"
  type        = string
}

variable "vlan20_ip" {
  description = "IP/prefix assigned to eth0.20 (k8s-svc VLAN)"
  type        = string
}

variable "vlan30_ip" {
  description = "IP/prefix assigned to eth0.30 (storage VLAN)"
  type        = string
}

variable "vrrp_vip_vlan10" {
  description = "VRRP virtual IP for vlan10"
  type        = string
}

variable "vrrp_vip_vlan20" {
  description = "VRRP virtual IP for vlan20"
  type        = string
}

variable "vrrp_vip_vlan30" {
  description = "VRRP virtual IP for vlan30"
  type        = string
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
