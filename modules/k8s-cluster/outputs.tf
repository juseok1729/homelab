output "control_plane_ips" {
  description = "Control plane 노드 IP 목록"
  value       = [for cp in local.control_planes : split("/", cp.ip)[0]]
}

output "worker_ips" {
  description = "Worker 노드 IP 목록"
  value       = [for w in local.workers : split("/", w.ip)[0]]
}

output "k8s_vip" {
  description = "API server VIP (kube-vip)"
  value       = var.k8s_vip
}

output "kubeconfig_path" {
  description = "로컬에 저장된 kubeconfig 경로"
  value       = module.bootstrap.kubeconfig_path
}

output "all_node_ips" {
  description = "BGP neighbor 구성용 전체 노드 IP"
  value = concat(
    [for cp in local.control_planes : split("/", cp.ip)[0]],
    [for w in local.workers : split("/", w.ip)[0]],
  )
}
