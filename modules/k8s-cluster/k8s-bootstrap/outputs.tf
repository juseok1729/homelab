output "kubeconfig_path" {
  description = "로컬에 저장된 kubeconfig 파일 경로"
  value       = var.kubeconfig_output_path
}

output "inventory_path" {
  description = "생성된 Ansible 인벤토리 파일 경로"
  value       = local_file.inventory.filename
}
