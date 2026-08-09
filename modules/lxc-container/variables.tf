variable "ct_id" {
  description = "Proxmox 컨테이너 ID"
  type        = number
}

variable "name" {
  description = "컨테이너 호스트명"
  type        = string
}

variable "node_name" {
  description = "배포할 PVE 노드"
  type        = string
}

variable "template_file_id" {
  description = "LXC 템플릿 file ID (예: local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst)"
  type        = string
}

variable "os_type" {
  description = "게스트 OS 타입 (proxmox ostype)"
  type        = string
  default     = "debian"
}

variable "description" {
  description = "컨테이너 설명"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Proxmox 태그 목록"
  type        = list(string)
  default     = []
}

variable "cores" {
  description = "vCPU 수"
  type        = number
  default     = 1
}

variable "memory" {
  description = "메모리 (MB)"
  type        = number
  default     = 512
}

variable "disk_size" {
  description = "rootfs 크기 (GB)"
  type        = number
  default     = 4
}

variable "datastore" {
  description = "rootfs 저장할 datastore"
  type        = string
}

variable "vlan_id" {
  description = "연결할 VLAN ID (vmbr0 trunk 기준)"
  type        = number
}

variable "ip_address" {
  description = "고정 IP (CIDR 표기, 예: 192.168.10.10/24)"
  type        = string
}

variable "gateway" {
  description = "기본 게이트웨이 (VRRP VIP)"
  type        = string
}

variable "ssh_public_keys" {
  description = "root 계정에 주입할 SSH 공개키 목록"
  type        = list(string)
  default     = []
}

variable "unprivileged" {
  description = "unprivileged 컨테이너 여부"
  type        = bool
  default     = true
}

variable "start_on_boot" {
  description = "노드 부팅 시 자동 시작"
  type        = bool
  default     = true
}

variable "nesting" {
  description = "nesting feature 활성화 (apt/systemd 동작에 필요)"
  type        = bool
  default     = true
}

variable "device_passthrough_paths" {
  description = "컨테이너로 전달할 호스트 디바이스 경로 목록 (예: /dev/net/tun)"
  type        = list(string)
  default     = []
}
