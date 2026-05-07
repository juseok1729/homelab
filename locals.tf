locals {
  vm_tags_router = ["vyos", "router", "homelab"]
  datastore      = "local-lvm"

  # k8s 노드 6개 전체를 VyOS BGP neighbor로 등록
  # remote_as = 65001 (Cilium BGP Control Plane AS)
  k8s_bgp_neighbors = [
    { ip = "192.168.20.11", remote_as = 65001 },
    { ip = "192.168.20.12", remote_as = 65001 },
    { ip = "192.168.20.13", remote_as = 65001 },
    { ip = "192.168.20.21", remote_as = 65001 },
    { ip = "192.168.20.22", remote_as = 65001 },
    { ip = "192.168.20.23", remote_as = 65001 },
  ]
}
