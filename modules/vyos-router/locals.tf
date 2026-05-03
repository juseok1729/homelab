locals {
  # Bootstrap IP from guest agent — skip link-local (169.254.x.x)
  bootstrap_ip = try(
    [for ip in proxmox_virtual_environment_vm.this.ipv4_addresses[1] : ip if !startswith(ip, "169.254")][0],
    null
  )

  # Derive network addresses from VLAN IPs for NAT rules
  vlan10_network = "${cidrhost(var.vlan10_ip, 0)}/${split("/", var.vlan10_ip)[1]}"
  vlan20_network = "${cidrhost(var.vlan20_ip, 0)}/${split("/", var.vlan20_ip)[1]}"
  vlan30_network = "${cidrhost(var.vlan30_ip, 0)}/${split("/", var.vlan30_ip)[1]}"

  vrrp_priority = var.role == "master" ? var.vrrp_priority_master : var.vrrp_priority_backup

  vrrp_config_block = <<-EOT
    set high-availability vrrp sync-group ALL member 'vrrp-vlan10'
    set high-availability vrrp sync-group ALL member 'vrrp-vlan20'
    set high-availability vrrp sync-group ALL member 'vrrp-vlan30'

    set high-availability vrrp group vrrp-vlan10 interface 'eth0.10'
    set high-availability vrrp group vrrp-vlan10 vrid '10'
    set high-availability vrrp group vrrp-vlan10 priority '${local.vrrp_priority}'
    set high-availability vrrp group vrrp-vlan10 advertise-interval '${var.vrrp_advertise_interval}'
    set high-availability vrrp group vrrp-vlan10 address '${var.vrrp_vip_vlan10}'

    set high-availability vrrp group vrrp-vlan20 interface 'eth0.20'
    set high-availability vrrp group vrrp-vlan20 vrid '20'
    set high-availability vrrp group vrrp-vlan20 priority '${local.vrrp_priority}'
    set high-availability vrrp group vrrp-vlan20 advertise-interval '${var.vrrp_advertise_interval}'
    set high-availability vrrp group vrrp-vlan20 address '${var.vrrp_vip_vlan20}'

    set high-availability vrrp group vrrp-vlan30 interface 'eth0.30'
    set high-availability vrrp group vrrp-vlan30 vrid '30'
    set high-availability vrrp group vrrp-vlan30 priority '${local.vrrp_priority}'
    set high-availability vrrp group vrrp-vlan30 advertise-interval '${var.vrrp_advertise_interval}'
    set high-availability vrrp group vrrp-vlan30 address '${var.vrrp_vip_vlan30}'
  EOT

  config_script = <<-EOT
    source /opt/vyatta/etc/functions/script-template
    configure

    set system host-name '${var.name}'

    set interfaces ethernet eth0 vif 10 address '${var.vlan10_ip}'
    set interfaces ethernet eth0 vif 10 description 'mgmt'
    set interfaces ethernet eth0 vif 20 address '${var.vlan20_ip}'
    set interfaces ethernet eth0 vif 20 description 'k8s-svc'
    set interfaces ethernet eth0 vif 30 address '${var.vlan30_ip}'
    set interfaces ethernet eth0 vif 30 description 'storage'

    set nat source rule 100 description 'vlan10 to internet'
    set nat source rule 100 outbound-interface name 'eth0'
    set nat source rule 100 source address '${local.vlan10_network}'
    set nat source rule 100 translation address 'masquerade'

    set nat source rule 110 description 'vlan20 to internet'
    set nat source rule 110 outbound-interface name 'eth0'
    set nat source rule 110 source address '${local.vlan20_network}'
    set nat source rule 110 translation address 'masquerade'

    set nat source rule 120 description 'vlan30 to internet'
    set nat source rule 120 outbound-interface name 'eth0'
    set nat source rule 120 source address '${local.vlan30_network}'
    set nat source rule 120 translation address 'masquerade'

    set firewall global-options state-policy established action 'accept'
    set firewall global-options state-policy related action 'accept'
    set firewall global-options state-policy invalid action 'drop'

    ${local.vrrp_config_block}

    commit
    save
    exit
  EOT
}
