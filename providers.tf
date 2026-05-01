provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token
  insecure  = true # 자체 서명 인증서

  ssh {
    agent    = true
    username = "root"
  }
}
