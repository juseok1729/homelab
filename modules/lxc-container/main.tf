resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  vm_id         = var.ct_id
  description   = var.description
  tags          = var.tags
  unprivileged  = var.unprivileged
  start_on_boot = var.start_on_boot
  started       = true

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = 0
  }

  disk {
    datastore_id = var.datastore
    size         = var.disk_size
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = var.vlan_id
  }

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  features {
    nesting = var.nesting
  }

  # /dev/net/tun 등 호스트 디바이스 전달 (PVE 8.2+)
  dynamic "device_passthrough" {
    for_each = var.device_passthrough_paths
    content {
      path = device_passthrough.value
    }
  }
}
