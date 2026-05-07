resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = var.description
  tags        = var.tags

  clone {
    vm_id     = var.template_id
    node_name = var.template_node
    full      = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.disk_size
    file_format  = "raw"
    discard      = "on"
  }

  # vlan20에 tagged로 연결
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  # cloud-init: 정적 IP, SSH 공개키 주입 (hostname은 VM name에서 자동 파생)
  initialization {
    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }
  }

  agent {
    enabled = true
    timeout = "5m"
  }

  serial_device {
    device = "socket"
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }
}
