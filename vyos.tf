# ─────────────────────────────────────────────────────────────
# vyos-rtr-1 VM
# ─────────────────────────────────────────────────────────────
resource "proxmox_virtual_environment_vm" "vyos_rtr_1" {
  name        = var.vyos_rtr_1_name
  vm_id       = var.vyos_rtr_1_vm_id
  node_name   = var.pve_node_name
  description = "VyOS HA router (master) - managed by Terraform"
  tags        = local.vm_tags_router

  # Clone from template
  clone {
    vm_id = var.vyos_template_id
    full  = true
  }

  # CPU
  cpu {
    cores = var.vyos_rtr_1_cores
    type  = "host"
  }

  # Memory
  memory {
    dedicated = var.vyos_rtr_1_memory
  }

  # Disk
  disk {
    datastore_id = local.datastore
    interface    = "scsi0"
    size         = var.vyos_rtr_1_disk_size
    file_format  = "raw"
  }

  # Network — single trunk interface
  # vmbr0 가 vlan-aware bridge이므로 VLAN tag 미지정 = trunk 모드
  # VyOS 안에서 'set interfaces ethernet eth0 vif 10/20/30' 으로 sub-interface 생성
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Guest agent
  agent {
    enabled = true
    timeout = "5m"
  }

  # Serial console (template과 일치)
  serial_device {
    device = "socket"
  }

  # 부팅 순서
  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  # Cloud-init drive는 template에 이미 있음
  # VyOS는 cloud-init을 안 읽지만, drive 자체는 유지 (PVE 인자 호환성)

  # 의도적으로 ipconfig는 미설정 (VyOS가 cloud-init 안 읽음)
  # IP는 template의 bootstrap config (DHCP) 그대로 동작

  lifecycle {
    ignore_changes = [
      # Clone 후 PVE가 자동 변경하는 일부 필드 무시
      network_device,
    ]
  }
}

# ─────────────────────────────────────────────────────────────
# Wait for guest agent + extract IP
# ─────────────────────────────────────────────────────────────

# bpg/proxmox provider는 VM 생성 직후 ipv4_addresses를 자동으로 채움
# (agent.enabled=true 때문)
# 우리는 이를 outputs.tf에서 노출만 하면 됨


# Phase2
# ─────────────────────────────────────────────────────────────
# vyos-rtr-1 — Production config injection
# ─────────────────────────────────────────────────────────────
resource "null_resource" "vyos_rtr_1_provision" {
  depends_on = [proxmox_virtual_environment_vm.vyos_rtr_1]

  triggers = {
    config_version = var.vyos_rtr_1_config_version
    vm_id          = proxmox_virtual_environment_vm.vyos_rtr_1.vm_id
  }

  connection {
    type     = "ssh"
    host     = local.vyos_rtr_1_ip
    user     = var.vyos_default_user
    password = var.vyos_default_password
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    inline = ["echo SSH ready"]
  }

  provisioner "remote-exec" {
    inline = [
      "vbash <<'VYOS_EOF'\n${local.vyos_rtr_1_config_script}\nVYOS_EOF",
    ]
  }
}

# ─────────────────────────────────────────────────────────
# vyos-rtr-2 VM (신규)
# ─────────────────────────────────────────────────────────
resource "proxmox_virtual_environment_vm" "vyos_rtr_2" {
  name        = var.vyos_rtr_2_name
  vm_id       = var.vyos_rtr_2_vm_id
  node_name   = var.vyos_rtr_2_node
  description = "VyOS HA router (backup) - managed by Terraform"
  tags        = local.vm_tags_router

  clone {
    vm_id = var.vyos_template_id
    full  = true

    # Template이 node1에 있는데 node2로 clone할 때 disk migration 필요
    node_name = "pve-node1"
  }

  cpu {
    cores = var.vyos_rtr_2_cores
    type  = "host"
  }

  memory {
    dedicated = var.vyos_rtr_2_memory
  }

  disk {
    datastore_id = local.datastore
    interface    = "scsi0"
    size         = var.vyos_rtr_2_disk_size
    file_format  = "raw"
  }

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
    ignore_changes = [
      network_device,
    ]
  }
}

# ─────────────────────────────────────────────────────────
# vyos-rtr-2 provision
# ─────────────────────────────────────────────────────────
resource "null_resource" "vyos_rtr_2_provision" {
  depends_on = [proxmox_virtual_environment_vm.vyos_rtr_2]

  triggers = {
    config_version = var.vyos_rtr_2_config_version
    vm_id          = proxmox_virtual_environment_vm.vyos_rtr_2.vm_id
  }

  connection {
    type     = "ssh"
    host     = local.vyos_rtr_2_ip
    user     = var.vyos_default_user
    password = var.vyos_default_password
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    inline = ["echo SSH ready"]
  }

  provisioner "remote-exec" {
    inline = [
      "vbash <<'VYOS_EOF'\n${local.vyos_rtr_2_config_script}\nVYOS_EOF",
    ]
  }
}
