packer {
  required_version = ">= 1.10.0"
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────────────────
variable "proxmox_url" {
  type    = string
  default = "https://192.168.219.11:8006/api2/json"
}

# username 형식: user@realm!tokenid  (시크릿 UUID는 proxmox_token에 별도 입력)
variable "proxmox_username" {
  type    = string
  default = "terraform@pve!provisioner"
}

variable "proxmox_token" {
  description = "API token secret UUID (e454f82c-... 부분만)"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  type    = string
  default = "pve-node1"
}

variable "vm_id" {
  type    = number
  default = 9000
}

variable "iso_url" {
  type    = string
  default = "https://github.com/vyos/vyos-nightly-build/releases/download/2026.04.13-0034-rolling/vyos-2026.04.13-0034-rolling-generic-amd64.iso"
}

variable "iso_checksum" {
  description = "SHA256 체크섬. 개발 중에는 'none', 운영에서는 'sha256:...' 권장"
  type        = string
  default     = "none"
}

variable "upstream_gateway" {
  description = "ISP 라우터 게이트웨이 (bootstrap DHCP 실패 시 static route용)"
  type        = string
  default     = "192.168.219.1"
}

variable "vyos_password" {
  description = "VyOS vyos 계정 비밀번호 (template에 baked-in)"
  type        = string
  default     = "vyos"
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────
# Source: Proxmox ISO builder
# ─────────────────────────────────────────────────────────────
source "proxmox-iso" "vyos" {
  # Proxmox 연결
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true

  # VM 설정
  node    = var.proxmox_node
  vm_id   = var.vm_id
  vm_name = "vyos-template"

  # ISO — Packer가 local storage에 다운로드 후 마운트
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  iso_storage_pool = "local"
  unmount_iso      = true

  # Hardware (user 수동 설치와 동일 스펙)
  memory   = 1024
  cores    = 1
  cpu_type = "host"
  os       = "l26"

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = "4G"
    storage_pool = "local-lvm"
    type         = "scsi"
    format       = "raw"
    discard      = true
  }

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Serial console (VyOS 설치 화면 출력용)
  serial_ports = ["socket"]
  vga {
    type = "serial0"
  }

  qemu_agent = true

  # cloud-init drive: VyOS가 읽지는 않지만 PVE 메커니즘 호환용
  cloud_init_storage_pool = "local-lvm"

  # Template 메타데이터
  template_name        = "vyos-template"
  template_description = "VyOS rolling template — built with Packer + Ansible"

  # SSH communicator (Ansible provisioner 연결용)
  communicator = "ssh"
  ssh_username = "vyos"
  ssh_password = var.vyos_password
  ssh_timeout  = "20m"

  # ── Boot sequence ─────────────────────────────────────────
  # 흐름: ISO 첫 부팅 → 로그인 → install image → 재부팅
  #       → 설치된 VyOS 부팅 → DHCP+SSH 설정 → Packer SSH 연결
  boot_wait = "30s"
  boot_command = [
    # ── Phase 1: ISO 환경 로그인 ─────────────────────────────
    "vyos<enter><wait3>",
    "vyos<enter><wait5>",

    # ── Phase 2: install image 대화형 응답 ───────────────────
    "install image<enter><wait5>",
    # Would you like to continue? [y/N]
    "y<enter><wait3>",
    # Image name (default)
    "<enter><wait3>",
    # Password for vyos user
    "${var.vyos_password}<enter><wait3>",
    "${var.vyos_password}<enter><wait3>",
    # Console type (default: S — serial)
    "<enter><wait3>",
    # Installation disk (default: /dev/sda)
    "<enter><wait5>",
    # Delete all data? [y/N]
    "y<enter><wait5>",
    # Use all free space? [Y/n]
    "<enter><wait90>",
    # Boot config file (default: 1)
    "<enter><wait30>",

    # ── Phase 3: 설치 완료 → 재부팅 ──────────────────────────
    "reboot<enter><wait5>",
    "y<enter><wait90>",

    # ── Phase 4: 설치된 VyOS 첫 부팅 로그인 ──────────────────
    "vyos<enter><wait3>",
    "${var.vyos_password}<enter><wait5>",

    # ── Phase 5: Packer SSH 연결을 위한 최소 네트워크 설정 ───
    # Ansible provisioner가 SSH로 접속하려면 DHCP IP와 SSH 서비스가 필요
    "configure<enter><wait2>",
    "set interfaces ethernet eth0 address dhcp<enter><wait2>",
    "set service ssh port 22<enter><wait2>",
    "set service ssh listen-address 0.0.0.0<enter><wait2>",
    "set protocols static route 0.0.0.0/0 next-hop ${var.upstream_gateway}<enter><wait2>",
    "commit<enter><wait10>",
    "save<enter><wait3>",
    "exit<enter>",
  ]
}

# ─────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────
build {
  name    = "vyos-template"
  sources = ["source.proxmox-iso.vyos"]

  # Ansible이 나머지 설정을 담당:
  # timezone, DNS, hostname, qemu-guest-agent 설치 및 검증
  provisioner "ansible" {
    playbook_file = "../../ansible/vyos-template/playbook.yml"
    user          = "vyos"
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--extra-vars", "ansible_become_pass=${var.vyos_password}",
    ]
  }
}
