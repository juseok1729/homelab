# ─────────────────────────────────────────────────────────────
# Ansible 인벤토리 파일 생성
# ─────────────────────────────────────────────────────────────
resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    control_planes = var.control_planes
    workers        = var.workers
  })
  filename        = "${path.module}/inventory.ini"
  file_permission = "0644"
}

# ─────────────────────────────────────────────────────────────
# SSH 접속 가능 여부 확인 (모든 노드)
# ─────────────────────────────────────────────────────────────
resource "null_resource" "wait_for_nodes" {
  for_each = toset(concat(
    [for cp in var.control_planes : cp.ip],
    [for w in var.workers : w.ip],
  ))

  triggers = {
    ip = each.value
  }

  provisioner "local-exec" {
    # timeout 명령 없이 순수 sh 루프로 구현 (macOS/Linux 호환)
    command = <<-EOT
      echo "Waiting for SSH on ${each.value}..."
      count=0
      until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ${var.ssh_private_key_path} ansible@${each.value} true 2>/dev/null; do
        sleep 5
        count=$((count + 5))
        if [ "$count" -ge 300 ]; then
          echo "Timeout: SSH not available on ${each.value} after 5 minutes"
          exit 1
        fi
      done
      echo "SSH ready: ${each.value}"
    EOT
  }
}

# ─────────────────────────────────────────────────────────────
# Ansible Playbook 실행
# ─────────────────────────────────────────────────────────────
resource "null_resource" "bootstrap" {
  depends_on = [
    null_resource.wait_for_nodes,
    local_file.inventory,
  ]

  triggers = {
    bootstrap_trigger = var.bootstrap_trigger
    inventory_hash    = local_file.inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook \
        -i ${local_file.inventory.filename} \
        --private-key ${var.ssh_private_key_path} \
        --extra-vars "k8s_vip=${var.k8s_vip}" \
        --extra-vars "pod_cidr=${var.pod_cidr}" \
        --extra-vars "service_cidr=${var.service_cidr}" \
        --extra-vars "k8s_bgp_as=${var.k8s_bgp_as}" \
        --extra-vars "vyos_bgp_as=${var.vyos_bgp_as}" \
        --extra-vars "vyos_vip=${var.vyos_vip}" \
        --extra-vars "kubeconfig_local_path=${var.kubeconfig_output_path}" \
        ${path.root}/ansible/k8s-bootstrap/playbook.yml
    EOT
  }
}
