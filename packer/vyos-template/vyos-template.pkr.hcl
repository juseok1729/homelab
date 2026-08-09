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
  default = "https://172.30.1.111:8006/api2/json"
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
  description = "ISP 라우터 게이트웨이"
  type        = string
  default     = "172.30.1.254"
}

variable "vyos_password" {
  description = "VyOS vyos 계정 비밀번호 (template에 baked-in)"
  type        = string
  default     = "vyos"
  sensitive   = true
}

variable "build_ip" {
  description = <<-EOT
    Packer 빌드 중 SSH 접속에 사용할 임시 고정 IP.
    - qemu-guest-agent가 없는 상태에서 Packer가 IP를 탐지할 수 없으므로 필수.
    - 빌드가 끝나면 shutdown_command가 DHCP로 리셋하므로 템플릿에 남지 않음.
    - 빌드 중 해당 IP가 다른 호스트와 충돌하지 않아야 함.
  EOT
  type        = string
  default     = "172.30.1.200"
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
  boot_iso {
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = "local"
    unmount          = true
  }

  # Hardware (수동 설치와 동일 스펙)
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

  # Packer는 VNC로 boot_command를 전송하므로 표준 VGA 사용.
  # serial0 설정은 template 완성 후 PVE에서 별도 추가:
  #   qm set <vm_id> --serial0 socket --vga serial0
  vga {
    type = "std"
  }

  # agent: enabled=1 으로 VM 설정 (Terraform clone 후 사용)
  qemu_agent = true

  # 부팅 순서: 디스크 우선 → 설치 전엔 BIOS가 CDROM으로 폴백, 설치 후엔 디스크 GRUB 사용
  # eject 명령 없이도 install 완료 후 재부팅 시 자동으로 디스크에서 부팅됨
  boot = "order=scsi0;ide2"

  # cloud-init drive: VyOS가 읽지는 않지만 PVE 메커니즘 호환용
  cloud_init_storage_pool = "local-lvm"

  # Template 메타데이터
  template_name        = "vyos-template"
  template_description = "VyOS rolling template — built with Packer + Ansible"

  # SSH communicator
  # ssh_host: build_ip를 직접 지정해 guest-agent 없이도 접속 가능
  communicator = "ssh"
  ssh_username = "vyos"
  ssh_password = var.vyos_password
  ssh_host     = var.build_ip
  ssh_timeout  = "20m"

  # ── Boot sequence ─────────────────────────────────────────
  # Phase 1: ISO 첫 부팅 → 로그인
  # Phase 2: install image 대화형 응답
  # Phase 3: 재부팅 (boot=order=scsi0;ide2 덕분에 디스크로 자동 부팅)
  # Phase 4: 설치된 VyOS 로그인
  # Phase 5: 고정 IP + SSH 설정 → Packer SSH 접속 대기
  boot_wait = "45s"
  boot_command = [
    # ── Phase 1: ISO 환경 로그인 ─────────────────────────────
    "vyos<enter><wait3>",
    "vyos<enter><wait3>",

    # ── Phase 2: install image 대화형 응답 ───────────────────
    "install image<enter><wait5>",
    # Would you like to continue? [y/N]
    "y<enter><wait3>",
    # Image name (default)
    "<enter><wait3>",
    # Password for vyos user
    "${var.vyos_password}<enter><wait3>",
    "${var.vyos_password}<enter><wait3>",
    # Console type: K (KVM/VGA)
    "K<enter><wait5>",
    # Installation disk — 디스크 탐색(Probing disks)이 끝날 때까지 대기
    "<enter><wait5>",
    # Delete all data? [y/N]
    "y<enter><wait5>",
    # Use all free space? [Y/n] — 파티션 + 설치 완료까지 대기
    "<enter><wait10>",
    # Boot config file (default: 1)
    "<enter><wait10>",

    # ── Phase 3: 재부팅 → 디스크 부팅 ───────────────────────
    # boot=order=scsi0;ide2 설정으로 GRUB이 설치된 디스크가 우선 부팅됨
    "reboot<enter><wait5>",
    "y<enter><wait90>",

    # ── Phase 4: 설치된 VyOS 첫 부팅 로그인 ──────────────────
    "vyos<enter><wait3>",
    "${var.vyos_password}<enter><wait5>",

    # ── Phase 5: 고정 IP + SSH 설정 ──────────────────────────
    "configure<enter><wait2>",
    "set interfaces ethernet eth0 address ${var.build_ip}/24<enter><wait2>",
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

  # Ansible: timezone, DNS, hostname, qemu-guest-agent 설치 및 검증
  provisioner "ansible" {
    playbook_file = "../../ansible/vyos-template/playbook.yml"
    user          = "vyos"
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--extra-vars", "ansible_become_pass=${var.vyos_password}",
    ]
  }

  # 마지막 단계: config.boot 직접 수정 후 종료
  # vbash commit 방식은 IP 변경 시 SSH SIGHUP → poweroff 미실행 문제 있음
  # sed로 config.boot 파일을 직접 수정 → IP 변경 없음 → SSH 유지 → poweroff 정상 실행
  provisioner "shell" {
    inline = [
      "sudo sed -i 's|address \"${var.build_ip}/24\"|address dhcp|' /config/config.boot",
      "nohup bash -c 'sleep 3 && sudo poweroff' </dev/null >/dev/null 2>&1 &"
    ]
    expect_disconnect = true
  }

  post-processor "shell-local" {
    inline = [
      # serial console (Terraform clone 후 qm terminal 가능하게)
      "ssh root@${split(":", split("//", var.proxmox_url)[1])[0]} 'qm set ${var.vm_id} --serial0 socket --vga serial0'",
      # cloud-init drive (PVE 호환)
      "ssh root@${split(":", split("//", var.proxmox_url)[1])[0]} 'qm set ${var.vm_id} --ide2 local-lvm:cloudinit --agent enabled=1'",
    ]
  }
}
