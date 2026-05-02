locals {
  # Common labels for all VMs
  vm_tags_router = ["vyos", "router", "homelab"]

  # Datastore (모든 노드 동일하게 local-lvm 사용)
  datastore = "local-lvm"

  # ─────────────────────────────────────────────────────────
  # Bootstrap IP from guest agent (각 라우터)
  # ─────────────────────────────────────────────────────────
  vyos_rtr_1_ip = try(
    [for ip in proxmox_virtual_environment_vm.vyos_rtr_1.ipv4_addresses[1] : ip if !startswith(ip, "169.254")][0],
    null
  )

  vyos_rtr_2_ip = try(
    [for ip in proxmox_virtual_environment_vm.vyos_rtr_2.ipv4_addresses[1] : ip if !startswith(ip, "169.254")][0],
    null
  )

  # ─────────────────────────────────────────────────────────
  # vyos-rtr-1 config script (Phase 3 + VRRP master)
  # ─────────────────────────────────────────────────────────

  # VRRP config block — role별 (master/backup) 동적 생성
  vrrp_config_block_for = {
    for role in ["master", "backup"] : role => <<-EOT
      set high-availability vrrp sync-group ALL member 'vrrp-vlan10'
      set high-availability vrrp sync-group ALL member 'vrrp-vlan20'
      set high-availability vrrp sync-group ALL member 'vrrp-vlan30'

      set high-availability vrrp group vrrp-vlan10 interface 'eth0.10'
      set high-availability vrrp group vrrp-vlan10 vrid '10'
      set high-availability vrrp group vrrp-vlan10 priority '${role == "master" ? var.vrrp_priority_master : var.vrrp_priority_backup}'
      set high-availability vrrp group vrrp-vlan10 advertise-interval '${var.vrrp_advertise_interval}'
      set high-availability vrrp group vrrp-vlan10 address '${var.vrrp_vip_vlan10}'

      set high-availability vrrp group vrrp-vlan20 interface 'eth0.20'
      set high-availability vrrp group vrrp-vlan20 vrid '20'
      set high-availability vrrp group vrrp-vlan20 priority '${role == "master" ? var.vrrp_priority_master : var.vrrp_priority_backup}'
      set high-availability vrrp group vrrp-vlan20 advertise-interval '${var.vrrp_advertise_interval}'
      set high-availability vrrp group vrrp-vlan20 address '${var.vrrp_vip_vlan20}'

      set high-availability vrrp group vrrp-vlan30 interface 'eth0.30'
      set high-availability vrrp group vrrp-vlan30 vrid '30'
      set high-availability vrrp group vrrp-vlan30 priority '${role == "master" ? var.vrrp_priority_master : var.vrrp_priority_backup}'
      set high-availability vrrp group vrrp-vlan30 advertise-interval '${var.vrrp_advertise_interval}'
      set high-availability vrrp group vrrp-vlan30 address '${var.vrrp_vip_vlan30}'
    EOT
  }
}

# ─────────────────────────────────────────────────────────
# Block 2: Config script — 위에서 정의한 vrrp_config_block_for를 참조
# ─────────────────────────────────────────────────────────
locals {
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

    ${local.vrrp_config_block_for["master"]}

    commit
    save
    exit
  EOT

  vyos_rtr_2_config_script = <<-EOT
    source /opt/vyatta/etc/functions/script-template
    configure

    set system host-name 'vyos-rtr-2'

    set interfaces ethernet eth0 vif 10 address '${var.vyos_rtr_2_vlan10_ip}'
    set interfaces ethernet eth0 vif 10 description 'mgmt'
    set interfaces ethernet eth0 vif 20 address '${var.vyos_rtr_2_vlan20_ip}'
    set interfaces ethernet eth0 vif 20 description 'k8s-svc'
    set interfaces ethernet eth0 vif 30 address '${var.vyos_rtr_2_vlan30_ip}'
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

    ${local.vrrp_config_block_for["backup"]}

    commit
    save
    exit
  EOT
}
