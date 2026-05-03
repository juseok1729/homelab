# module: lxc-container

Planned generic module for deploying Proxmox LXC containers.
First consumer: `tailscale-gw` — a lightweight Tailscale exit node / subnet router.

## Planned topology

| Container | Role | Node | CTID | vCPU | RAM | VLAN |
|-----------|------|------|------|------|-----|------|
| tailscale-gw | Tailscale subnet router | pve-node1 | 310 | 1 | 512 | vlan10 |

## Planned inputs

- `ct_id` — Proxmox container ID
- `name` — container hostname
- `node_name` — PVE node to deploy on
- `template` — LXC template (e.g. `local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst`)
- `cores` — vCPU count
- `memory` — RAM in MB
- `disk_size` — rootfs size in GB
- `vlan_id` — target VLAN
- `ip_address` — static IP/prefix for the container
- `gateway` — default gateway (VRRP VIP from vyos-router module)
- `unprivileged` — whether to run as unprivileged container (default: true)

## Planned outputs

- `ct_id`
- `ip_address`
- `ssh_command`

## tailscale-gw specifics

- Requires `net.ipv4.ip_forward = 1` in container sysctl
- Advertises routes: `192.168.10.0/24`, `192.168.20.0/24`, `192.168.30.0/24`
- Auth key injected via `TF_VAR_tailscale_auth_key` (sensitive)
