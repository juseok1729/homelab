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
  }

  # vmbr0 is a vlan-aware bridge — no VLAN tag here means trunk mode.
  # VyOS creates sub-interfaces (eth0.10/20/30) internally.
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
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

  lifecycle {
    ignore_changes = [network_device]
  }
}

resource "null_resource" "provision" {
  depends_on = [proxmox_virtual_environment_vm.this]

  triggers = {
    config_version = var.config_version
    vm_id          = proxmox_virtual_environment_vm.this.vm_id
  }

  connection {
    type     = "ssh"
    host     = local.bootstrap_ip
    user     = var.default_user
    password = var.default_password
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    inline = ["echo SSH ready"]
  }

  provisioner "remote-exec" {
    inline = [
      "vbash <<'VYOS_EOF'\n${local.config_script}\nVYOS_EOF",
    ]
  }
}
