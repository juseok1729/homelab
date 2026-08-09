output "ct_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}

output "ip_address" {
  description = "컨테이너 고정 IP (prefix 제외)"
  value       = split("/", var.ip_address)[0]
}

output "ssh_command" {
  value = "ssh root@${split("/", var.ip_address)[0]}"
}
