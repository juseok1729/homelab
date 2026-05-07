variable "control_planes" {
  description = "Control plane 노드 목록"
  type = list(object({
    name = string
    ip   = string
  }))
}

variable "workers" {
  description = "Worker 노드 목록"
  type = list(object({
    name = string
    ip   = string
  }))
}

variable "ssh_private_key_path" {
  description = "Ansible SSH 접속용 개인키 경로"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "k8s_vip" {
  description = "kube-vip API server VIP"
  type        = string
  default     = "192.168.20.10"
}

variable "pod_cidr" {
  description = "Pod 네트워크 CIDR"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Service 네트워크 CIDR"
  type        = string
  default     = "10.96.0.0/12"
}

variable "k8s_bgp_as" {
  description = "K8s 클러스터 BGP AS 번호"
  type        = number
  default     = 65001
}

variable "vyos_bgp_as" {
  description = "VyOS BGP AS 번호"
  type        = number
  default     = 65000
}

variable "vyos_vip" {
  description = "VyOS VRRP VIP (BGP peer address)"
  type        = string
  default     = "192.168.20.1"
}

variable "kubeconfig_output_path" {
  description = "kubeconfig를 저장할 로컬 경로"
  type        = string
  default     = "~/.kube/homelab-config"
}

variable "bootstrap_trigger" {
  description = "재부트스트랩을 위해 bump하는 트리거 문자열"
  type        = string
  default     = "v1"
}
