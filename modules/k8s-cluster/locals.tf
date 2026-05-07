locals {
  # ── Control plane 노드 정의 ────────────────────────────────
  # VM ID: 211-213, IP: 192.168.20.11-13
  control_planes = [
    { name = "k8s-cp1", vm_id = 211, node = "pve-node1", ip = "192.168.20.11/24" },
    { name = "k8s-cp2", vm_id = 212, node = "pve-node2", ip = "192.168.20.12/24" },
    { name = "k8s-cp3", vm_id = 213, node = "pve-node3", ip = "192.168.20.13/24" },
  ]

  # ── Worker 노드 정의 ───────────────────────────────────────
  # VM ID: 221-223, IP: 192.168.20.21-23
  # w1은 node1 여유 자원을 활용해 더 큰 스펙 할당
  workers = [
    { name = "k8s-w1", vm_id = 221, node = "pve-node1", ip = "192.168.20.21/24", cores = 4, memory = 8192, disk_size = 50 },
    { name = "k8s-w2", vm_id = 222, node = "pve-node2", ip = "192.168.20.22/24", cores = 2, memory = 4096, disk_size = 30 },
    { name = "k8s-w3", vm_id = 223, node = "pve-node3", ip = "192.168.20.23/24", cores = 2, memory = 4096, disk_size = 30 },
  ]

  # bootstrap 모듈에 넘길 형태 (순수 IP)
  cp_bootstrap = [
    for cp in local.control_planes : {
      name = cp.name
      ip   = split("/", cp.ip)[0]
    }
  ]

  worker_bootstrap = [
    for w in local.workers : {
      name = w.name
      ip   = split("/", w.ip)[0]
    }
  ]

  tags_cp     = ["k8s", "control-plane", "homelab"]
  tags_worker = ["k8s", "worker", "homelab"]
}
