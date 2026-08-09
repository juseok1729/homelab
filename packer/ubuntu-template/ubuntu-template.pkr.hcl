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

variable "proxmox_username" {
  type    = string
  default = "terraform@pve!provisioner"
}

variable "proxmox_token" {
  description = "API token secret UUID"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  type    = string
  default = "pve-node1"
}

variable "vm_id" {
  type    = number
  default = 9001
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso"
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

variable "ssh_password" {
  description = "Packer SSH 접속용 평문 비밀번호 (autoinstall identity와 동일해야 함)"
  type        = string
  default     = "ubuntu"
  sensitive   = true
}

variable "ssh_password_hash" {
  description = <<-EOT
    ansible 계정 SHA-512 해시. 생성 방법:
      openssl passwd -6 ubuntu
    또는:
      python3 -c "import crypt; print(crypt.crypt('ubuntu', crypt.mksalt(crypt.METHOD_SHA512)))"
  EOT
  type        = string
  sensitive   = true
}

variable "build_ip" {
  description = <<-EOT
    Packer 빌드 중 SSH 접속에 사용할 임시 고정 IP.
    VyOS 빌드 IP(219.200)와 충돌하지 않도록 .201 사용.
    빌드 완료 후 shell provisioner가 DHCP로 리셋.
  EOT
  type        = string
  default     = "172.30.1.201"
}

# ─────────────────────────────────────────────────────────────
# Source: Proxmox ISO builder
# ─────────────────────────────────────────────────────────────
source "proxmox-iso" "ubuntu" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true

  node    = var.proxmox_node
  vm_id   = var.vm_id
  vm_name = "ubuntu-template"

  boot_iso {
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = "local"
    unmount          = true
  }

  memory   = 2048
  cores    = 2
  cpu_type = "host"
  os       = "l26"

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = "10G"
    storage_pool = "local-lvm"
    type         = "scsi"
    format       = "raw"
    discard      = true
  }

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Packer VNC 전송용 — serial0은 post-processor에서 추가
  vga {
    type = "std"
  }

  qemu_agent = true
  boot       = "order=scsi0;ide2"

  cloud_init_storage_pool = "local-lvm"

  template_name        = "ubuntu-template"
  template_description = "Ubuntu 24.04 LTS template — built with Packer + Ansible"

  # build_ip를 고정으로 지정 → guest-agent 없이도 SSH 접속 가능
  communicator           = "ssh"
  ssh_username           = "ansible"
  ssh_password           = var.ssh_password
  ssh_host               = var.build_ip
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 500

  # GRUB command line에서 autoinstall 파라미터 주입
  # 'c'로 GRUB prompt 진입 → linux/initrd 명령으로 직접 부팅
  boot_wait = "8s"
  boot_command = [
    "c<wait2>",
    "linux /casper/vmlinuz autoinstall quiet ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter><wait3>",
    "initrd /casper/initrd<enter><wait3>",
    "boot<enter>",
  ]

  # http_content: 동적으로 user-data 생성 (비밀번호 해시, 빌드 IP 주입)
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data.pkrtpl", {
      ssh_password_hash = var.ssh_password_hash
      build_ip          = var.build_ip
      upstream_gateway  = var.upstream_gateway
    })
    "/meta-data" = ""
  }
}

# ─────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────
build {
  name    = "ubuntu-template"
  sources = ["source.proxmox-iso.ubuntu"]

  # k8s 사전 패키지 설치 (containerd, kubeadm 등) + SSH 경화
  provisioner "ansible" {
    playbook_file = "../../ansible/ubuntu-template/playbook.yml"
    user          = "ansible"
    extra_arguments = [
      "--extra-vars", "ansible_become=true ansible_become_method=sudo",
    ]
  }

  # cloud-init 상태 초기화 + 빌드 IP → DHCP로 리셋
  # cloud-init이 clone 후 첫 부팅 시 Proxmox가 주입한 IP/hostname/key를 적용함
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id",
      "sudo rm -f /etc/hostname",
      # 빌드 IP 제거 → DHCP fallback (cloud-init이 static IP 재설정)
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "sudo tee /etc/netplan/01-dhcp.yaml > /dev/null << 'EOF'\nnetwork:\n  version: 2\n  ethernets:\n    ens18:\n      dhcp4: true\nEOF",
      "nohup bash -c 'sleep 3 && sudo poweroff' </dev/null >/dev/null 2>&1 &",
    ]
    expect_disconnect = true
  }

  # serial console + cloud-init drive 추가 (VyOS 템플릿과 동일 패턴)
  post-processor "shell-local" {
    inline = [
      "ssh root@${split(":", split("//", var.proxmox_url)[1])[0]} 'qm set ${var.vm_id} --serial0 socket --vga serial0'",
      "ssh root@${split(":", split("//", var.proxmox_url)[1])[0]} 'qm set ${var.vm_id} --ide2 local-lvm:cloudinit --agent enabled=1'",
    ]
  }
}
