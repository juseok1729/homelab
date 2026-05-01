locals {
  # Common labels for all VMs
  vm_tags_router = ["vyos", "router", "homelab"]

  # Datastore (모든 노드 동일하게 local-lvm 사용)
  datastore = "local-lvm"
}
