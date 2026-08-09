# module: lxc-container

Generic module for deploying Proxmox LXC containers.
First consumer: `tailscale-gw` — a Tailscale subnet router ([docs/tailscale-gw.md](../../docs/tailscale-gw.md)).

## Current consumers

| Container | Role | Node | CTID | vCPU | RAM | VLAN |
|-----------|------|------|------|------|-----|------|
| tailscale-gw | Tailscale subnet router | pve-node1 | 310 | 1 | 512 | vlan10 |

## Inputs

- `ct_id` — Proxmox container ID
- `name` — container hostname
- `node_name` — PVE node to deploy on
- `template_file_id` — LXC template file ID (e.g. `local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst`)
- `os_type` — guest ostype (default: `debian`)
- `cores` / `memory` / `disk_size` — 1 vCPU / 512 MB / 4 GB by default
- `datastore` — rootfs datastore
- `vlan_id` — target VLAN (vmbr0 trunk)
- `ip_address` — static IP/prefix for the container
- `gateway` — default gateway (VRRP VIP from vyos-router module)
- `ssh_public_keys` — keys injected into root account
- `unprivileged` — default true
- `device_passthrough_paths` — host devices to pass through (e.g. `/dev/net/tun`, requires PVE 8.2+)

## Outputs

- `ct_id`
- `ip_address`
- `ssh_command`

## tailscale-gw specifics

Provisioning (tailscale install + `tailscale up`) lives in root `main.tf` as
`null_resource.tailscale_gw_provision`, executed via `pct exec` over SSH to the PVE node.
It only runs when `tailscale_auth_key` is set, and re-runs when
`tailscale_gw_config_version` is bumped.

- `net.ipv4.ip_forward=1` set inside the container
- Advertises routes from `tailscale_advertise_routes` (vlan10/20/30 + 172.30.1.0/24)
- Auth key injected via `terraform.tfvars` (sensitive, gitignored)
