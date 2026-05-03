# module: k8s-cluster

Planned module for deploying a Kubernetes cluster on Proxmox VMs.

## Planned topology

| VM | Role | Node | VMID | vCPU | RAM | VLAN |
|----|------|------|------|------|-----|------|
| k8s-cp-1 | control-plane | pve-node1 | 211 | 4 | 4096 | vlan20 |
| k8s-cp-2 | control-plane | pve-node2 | 212 | 4 | 4096 | vlan20 |
| k8s-cp-3 | control-plane | pve-node3 | 213 | 4 | 4096 | vlan20 |
| k8s-wk-1 | worker | pve-node1 | 221 | 8 | 8192 | vlan20 |
| k8s-wk-2 | worker | pve-node2 | 222 | 8 | 8192 | vlan20 |
| k8s-wk-3 | worker | pve-node3 | 223 | 8 | 8192 | vlan20 |

## Planned inputs

- `node_count` — number of control-plane / worker nodes
- `template_id` — Ubuntu/Debian cloud-init template VM ID
- `vlan_id` — target VLAN (default: 20, k8s-svc)
- `default_gateway` — VRRP VIP from the vyos-router module (`vrrp_vip_vlan20`)
- `kubeconfig_output_path` — where to write the merged kubeconfig

## Dependencies

- `module.vyos_rtr_1` and `module.vyos_rtr_2` must be applied first.
- Default gateway for k8s nodes: `192.168.20.1` (VRRP VIP on vlan20).
