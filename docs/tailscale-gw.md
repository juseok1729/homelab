# Tailscale Gateway — 외부 원격 접근 구성

> **작성일**: 2026-08-09
> REFACTORING.md Phase 5 설계의 구현. 외부에서 Tailscale VPN으로 홈랩 내부(K8s, Proxmox)에 접근한다.

## 구성

```
[외부 기기: Mac/폰]
   │ tailscale (100.x.x.x)
   ▼
[Tailscale 중계/직결]
   │
   ▼
[tailscale-gw]  LXC CT 310, vlan10 (192.168.10.10)
   │ subnet router — 광고 경로:
   │   192.168.10.0/24 (mgmt vlan)
   │   192.168.20.0/24 (k8s-svc — K8s API 192.168.20.10)
   │   192.168.30.0/24 (storage)
   │   172.30.1.0/24   (관리 네트워크 — Proxmox 노드)
   ▼
[VyOS HA 라우터] → 각 VLAN / 관리 네트워크
```

- **모듈**: `modules/lxc-container` (범용 LXC 모듈, 첫 소비자가 tailscale-gw)
- **컨테이너**: Debian 12, unprivileged, `/dev/net/tun` device passthrough (PVE 8.2+)
- **템플릿**: Terraform이 `proxmox_virtual_environment_download_file`로 자동 다운로드
- **프로비저닝**: pve-node1에 SSH → `pct exec`로 컨테이너 내부에서 tailscale 설치/활성화.
  `tailscale_auth_key`가 비어 있으면 컨테이너만 만들고 이 단계는 건너뜀 (count 조건)

## 배포 절차

### 1. Tailscale auth key 발급

[admin console → Settings → Keys](https://login.tailscale.com/admin/settings/keys)에서
**Auth key** 생성. 권장 옵션:

- Reusable: off (1회용이면 충분)
- Expiration: 짧게 (등록 후에는 불필요)
- Ephemeral: **off** (컨테이너 재시작 시에도 노드 유지)
- Tags: 사용 중이면 `tag:homelab` 등 지정

### 2. terraform.tfvars에 키 추가

```hcl
tailscale_auth_key = "tskey-auth-..."
```

### 3. Apply

```bash
terraform apply
# 생성: 템플릿 다운로드 → CT 310 → tailscale 설치 + up (subnet router)
```

### 4. 광고 경로 승인

auth key에 route auto-approve가 없다면 [admin console → Machines](https://login.tailscale.com/admin/machines)에서
`tailscale-gw`의 **Edit route settings**로 광고된 4개 경로를 승인한다.

ACL로 자동 승인하려면 (권장):

```json
"autoApprovers": {
  "routes": {
    "192.168.10.0/24": ["ojkk371@gmail.com"],
    "192.168.20.0/24": ["ojkk371@gmail.com"],
    "192.168.30.0/24": ["ojkk371@gmail.com"],
    "172.30.1.0/24":   ["ojkk371@gmail.com"]
  }
}
```

### 5. 클라이언트 확인 (외부 네트워크에서)

```bash
tailscale status                          # tailscale-gw 노드 보이는지
ping 192.168.10.10                        # gw 자체
kubectl --kubeconfig ~/.kube/homelab-config get node   # K8s API (192.168.20.10)
open https://172.30.1.111:8006            # Proxmox web UI
```

macOS/iOS 클라이언트는 "Use Tailscale subnets" 옵션이 켜져 있어야 한다.

## 운영

| 작업 | 방법 |
|------|------|
| tailscale 재프로비저닝 | `tailscale_gw_config_version` bump 후 apply |
| 광고 경로 변경 | `tailscale_advertise_routes` 수정 + config_version bump |
| 컨테이너 접속 | `ssh root@192.168.10.10` (k8s SSH 키) 또는 pve-node1에서 `pct enter 310` |
| 상태 확인 | `pct exec 310 -- tailscale status` |

## 주의사항

- **auth key는 tfstate에 평문 저장**된다 (sensitive 표시만 됨). 로컬 state이므로 허용하지만,
  키를 1회용 + 짧은 만료로 발급하면 유출 영향이 없다.
- **172.30.1.0/24 경로의 리턴 경로**: 현재는 VyOS가 vlan10 → 관리망 트래픽을 masquerade하므로
  동작한다. 단, [mgmt-network-nat-update.md](mgmt-network-nat-update.md)의 NAT 제외를 적용하면
  Proxmox 노드가 192.168.10.x로 직접 응답해야 하므로, **각 PVE 노드에 정적 경로 추가가 필요**:

  ```bash
  # 각 pve-node에서 (VyOS vlan1 IP 경유)
  echo "ip route add 192.168.10.0/24 via 172.30.1.64" >> /etc/network/interfaces.d/...
  ```

  NAT 갱신 작업 시 함께 처리할 것 (해당 문서에도 표기됨).
- 집 안에서 tailscale이 켜져 있어도 로컬 LAN이 우선이므로 성능 저하는 없다.
