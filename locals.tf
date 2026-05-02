locals {
  # Common labels for all VMs
  vm_tags_router = ["vyos", "router", "homelab"]

  # Datastore (모든 노드 동일하게 local-lvm 사용)
  datastore = "local-lvm"

  # Bootstrap IP from guest agent
  vyos_rtr_1_ip = try(
    [for ip in proxmox_virtual_environment_vm.vyos_rtr_1.ipv4_addresses[1] : ip if !startswith(ip, "169.254")][0],
    null
  )

  # VyOS configure script — runs inside vbash via heredoc
  vyos_rtr_1_config_script = <<-EOT
    source /opt/vyatta/etc/functions/script-template
    configure

    set system host-name 'vyos-rtr-1'

    set interfaces ethernet eth0 vif 10 address '${var.vyos_rtr_1_vlan10_ip}'
    set interfaces ethernet eth0 vif 10 description 'mgmt'
    set interfaces ethernet eth0 vif 20 address '${var.vyos_rtr_1_vlan20_ip}'
    set interfaces ethernet eth0 vif 20 description 'k8s-svc'
    set interfaces ethernet eth0 vif 30 address '${var.vyos_rtr_1_vlan30_ip}'
    set interfaces ethernet eth0 vif 30 description 'storage'

    set nat source rule 100 description 'vlan10 to internet'
    set nat source rule 100 outbound-interface name 'eth0'
    set nat source rule 100 source address '192.168.10.0/24'
    set nat source rule 100 translation address 'masquerade'

    set nat source rule 110 description 'vlan20 to internet'
    set nat source rule 110 outbound-interface name 'eth0'
    set nat source rule 110 source address '192.168.20.0/24'
    set nat source rule 110 translation address 'masquerade'

    set nat source rule 120 description 'vlan30 to internet'
    set nat source rule 120 outbound-interface name 'eth0'
    set nat source rule 120 source address '192.168.30.0/24'
    set nat source rule 120 translation address 'masquerade'

    set firewall global-options state-policy established action 'accept'
    set firewall global-options state-policy related action 'accept'
    set firewall global-options state-policy invalid action 'drop'

    commit
    save
    exit
  EOT
}
