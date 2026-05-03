# State path migration: flat → modular structure
# These blocks let `terraform apply` silently remap existing state
# without destroying/recreating any real infrastructure.
# Safe to remove after the first successful `terraform apply`.

moved {
  from = proxmox_virtual_environment_vm.vyos_rtr_1
  to   = module.vyos_rtr_1.proxmox_virtual_environment_vm.this
}

moved {
  from = null_resource.vyos_rtr_1_provision
  to   = module.vyos_rtr_1.null_resource.provision
}

moved {
  from = proxmox_virtual_environment_vm.vyos_rtr_2
  to   = module.vyos_rtr_2.proxmox_virtual_environment_vm.this
}

moved {
  from = null_resource.vyos_rtr_2_provision
  to   = module.vyos_rtr_2.null_resource.provision
}
