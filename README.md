# Homelab IaC

Proxmox VE 3노드 위에 VyOS HA 라우터와 Kubernetes HA 클러스터를
Terraform + Packer + Ansible로 완전 자동화한 홈랩 인프라입니다.

---

## 기술 스택

| 레이어 | 기술 | 역할 |
|---|---|---|
| 하이퍼바이저 | Proxmox VE | 3노드 클러스터 |
| 템플릿 빌드 | Packer + Ansible | VyOS / Ubuntu 템플릿 자동화 |
| 인프라 프로비저닝 | Terraform (bpg/proxmox) | VM 생성 + 설정 |
| 라우터 | VyOS (rolling) | VLAN 라우팅, NAT, VRRP HA, BGP |
| 쿠버네티스 | kubeadm 1.32 + stacked etcd | 3 CP + 3 Worker HA 클러스터 |
| VIP 관리 | kube-vip v0.8.7 | API server HA VIP (ARP + k8s lease) |
| CNI | Cilium 1.17 | eBPF native routing, kube-proxy 대체, BGP |
| 컨테이너 런타임 | containerd 2.x | SystemdCgroup 설정 |

---

## 활성화된 주요 기능

### VyOS HA (VRRP)
- vyos-rtr-1(master) / vyos-rtr-2(backup) 이중화
- VRID 10/20/30, sync-group ALL, 광고 주기 1s
- **근거**: 라우터 단일 장애점 제거. master 다운 시 1~2초 내 backup이 VIP 인계

### Cilium eBPF Native Routing
- kube-proxy 제거 (`kubeProxyReplacement=true`)
- `routingMode=native`: VXLAN 터널링 없이 L3 직접 라우팅
- `bpf.masquerade=true`: iptables 대신 eBPF로 SNAT
- **근거**: iptables 규칙 수가 서비스에 비례해 증가하는 문제 해결. 홈랩이지만 실제 기술 학습 목적

### Cilium BGP Control Plane
- 각 노드가 자신의 Pod CIDR을 VyOS에 BGP로 광고
- VyOS가 Pod CIDR 라우트를 학습 → 외부에서 Pod IP 직접 접근 가능
- **근거**: LoadBalancer 서비스 없이도 내부 네트워크에서 Pod에 직접 접근, L3 라우팅 학습

### Hubble 네트워크 가시성
- Cilium 내장 Hubble Agent + Relay + UI 활성화
- 실시간 서비스 간 네트워크 플로우 시각화
- DNS, HTTP, TCP, 드롭 패킷 메트릭 수집
- **근거**: eBPF 기반 관찰이라 iptables 룰 없이 커널 레벨에서 패킷 추적 가능. 네트워크 정책 디버깅에 유용

### kube-vip Lease 기반 HA
- k8s lease로 리더 선출 → 단일 노드만 VIP 보유
- kube-vip.conf에 노드 자신의 IP 기재 → 재부팅 후 VIP 없이도 API 서버 연결 가능
- **근거**: 노드 재시작 후 닭-달걀 문제(VIP 없이 API 연결 불가) 해결

---

## VM 배치 토폴로지

```mermaid
flowchart TB
    subgraph Node1["🖥️ pve-node1 · Lenovo M70q Gen 6 · 32GB / 14c"]
        direction TB
        VY1["🌐 vyos-rtr-1<br/>2c · 2GB · 10GB<br/>VRRP master"]
        CP1["🔵 k8s-cp1  (211)<br/>2c · 4GB · 30GB<br/>192.168.20.11"]
        W1["🟢 k8s-w1  (221)<br/>4c · 8GB · 50GB<br/>192.168.20.21"]
        T1["📦 vyos-template (9000)<br/>ubuntu-template (9001)"]
    end

    subgraph Node2["🖥️ pve-node2 · Dell OptiPlex 7070 Micro · 16GB / 6c"]
        direction TB
        VY2["🌐 vyos-rtr-2<br/>2c · 2GB · 10GB<br/>VRRP backup"]
        CP2["🔵 k8s-cp2  (212)<br/>2c · 4GB · 30GB<br/>192.168.20.12"]
        W2["🟢 k8s-w2  (222)<br/>2c · 4GB · 30GB<br/>192.168.20.22"]
    end

    subgraph Node3["🖥️ pve-node3 · Dell OptiPlex 7070 Micro · 16GB / 6c"]
        direction TB
        CP3["🔵 k8s-cp3  (213)<br/>2c · 4GB · 30GB<br/>192.168.20.13"]
        W3["🟢 k8s-w3  (223)<br/>2c · 4GB · 30GB<br/>192.168.20.23"]
    end

    Node1 ~~~ Node2
    Node2 ~~~ Node3

    classDef router fill:#FAEEDA,stroke:#854F0B,color:#412402
    classDef cp fill:#E6F1FB,stroke:#185FA5,color:#042C53
    classDef worker fill:#E1F5EE,stroke:#0F6E56,color:#04342C
    classDef tmpl fill:#F5F5F5,stroke:#999,color:#555

    class VY1,VY2 router
    class CP1,CP2,CP3 cp
    class W1,W2,W3 worker
    class T1 tmpl
```

**K8s VIP**: `192.168.20.10` (kube-vip) · **API server**: `https://192.168.20.10:6443`

---

## 네트워크 토폴로지

```mermaid
flowchart TD
    classDef isp    fill:#f39c12,stroke:#e67e22,stroke-width:2px,color:#fff
    classDef sw     fill:#34495e,stroke:#2c3e50,stroke-width:2px,color:#fff
    classDef desk   fill:#7f8c8d,stroke:#34495e,stroke-width:2px,color:#fff
    classDef access fill:#2ecc71,stroke:#27ae60,stroke-width:2px,color:#fff
    classDef trunk  fill:#3498db,stroke:#2980b9,stroke-width:2px,color:#fff
    classDef pve    fill:#9b59b6,stroke:#8e44ad,stroke-width:2px,color:#fff
    classDef vyos   fill:#e67e22,stroke:#d35400,stroke-width:2px,color:#fff
    classDef k8s    fill:#2980b9,stroke:#1a5276,stroke-width:2px,color:#fff

    subgraph External["External"]
        ISP["ISP 라우터<br/>192.168.219.1<br/>NAT + DHCP"]:::isp
    end

    subgraph SW["MikroTik CRS310-8G+2S+<br/>(VLAN Filtering ON)"]
        P1["ether1 (Uplink)"]:::access
        P2["ether2 (Desktop)"]:::access
        P3["ether3 → pve-node1"]:::trunk
        P4["ether4 → pve-node2"]:::trunk
        P5["ether5 → pve-node3"]:::trunk
    end

    ISP ---|VLAN1| P1
    P2 ---|VLAN1| PC["개발 Mac\n192.168.219.x"]:::desk
    P3 ---|"Trunk\n1u·10·20·30"| N1["pve-node1\nvmbr0"]:::pve
    P4 ---|"Trunk\n1u·10·20·30"| N2["pve-node2\nvmbr0"]:::pve
    P5 ---|"Trunk\n1u·10·20·30"| N3["pve-node3\nvmbr0"]:::pve

    subgraph VYOS["VyOS VRRP HA"]
        VR["eth0.10 → 192.168.10.1 (VIP)<br/>eth0.20 → 192.168.20.1 (VIP) ← K8s GW<br/>eth0.30 → 192.168.30.1 (VIP)"]:::vyos
    end

    subgraph K8S["K8s Cluster (VLAN20)"]
        KV["kube-vip 192.168.20.10"]:::k8s
    end

    N1 & N2 & N3 --- VR
    VR --- KV
```

**VLAN 대역:**
- `VLAN1` 192.168.219.x — 관리망 (ISP)
- `VLAN10` 192.168.10.0/24 — mgmt
- `VLAN20` 192.168.20.0/24 — K8s 클러스터
- `VLAN30` 192.168.30.0/24 — storage (예정)

---

## 문서

| 문서 | 내용 |
|---|---|
| [docs/setup.md](docs/setup.md) | **처음부터 따라하는 셋업 가이드** |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 코드베이스 구조 학습 가이드 |
| [docs/kube-vip-bootstrap.md](docs/kube-vip-bootstrap.md) | kube-vip HA 설계 및 트러블슈팅 |
| [docs/bgp-peering.md](docs/bgp-peering.md) | VyOS ↔ Cilium BGP 피어링 |
| [docs/cilium-ebpf.md](docs/cilium-ebpf.md) | Cilium eBPF 구성 상세 |
| [docs/nic-hang-fix.md](docs/nic-hang-fix.md) | Intel I219-LM NIC 행업 처치 |
| [docs/REFACTORING.md](docs/REFACTORING.md) | IaC 리팩토링 기록 |

---

## 개발 이력

<details>
<summary>Phase 0: VyOS Template 수동 제작</summary>

- [x] VyOS Rolling ISO에 cloud-init 부재 확인
- [x] Default apt repo 비활성 상태에서 외부 repo 일회성 활용
- [x] qemu-guest-agent 설치로 PVE → guest IP 자동 발견
- [x] Bootstrap config로 clone 후 즉시 SSH 도달 가능
- [x] Template lock + cloud-init drive 부착
- [x] Clone 검증 완료

</details>

<details>
<summary>Phase 1: Terraform 첫 번째 VM 프로비저닝</summary>

- [x] PVE API 토큰 발급 (terraform@pve!provisioner)
- [x] bpg/proxmox provider 0.66 설치 + 인증
- [x] Template clone 첫 사이클 (apply 0 error)
- [x] Guest agent 통한 IP 자동 발견
- [x] SSH 도달성 검증

</details>

<details>
<summary>Phase 2: vyos-rtr-1 네트워크 설정</summary>

- [x] Hostname, VLAN sub-interface (eth0.10/20/30)
- [x] NAT masquerade (vlan10/20/30 → eth0)
- [x] Firewall state-policy
- [x] External SSH 유지 (vlan1 DHCP fallback)

</details>

<details>
<summary>Phase 3: VRRP HA 이중화</summary>

- [x] Master(priority 200) / Backup(priority 100) 분리
- [x] VRID 10/20/30 매칭
- [x] Sync-group ALL 동작 확인
- [x] Failover 검증

</details>

<details>
<summary>Phase 4: IaC 리팩토링 + VyOS 템플릿 자동화</summary>

**Terraform 모듈화**
- [x] 평면 구조 → `modules/vyos-router/` 분리
- [x] `role = "master"|"backup"` 변수로 VRRP 우선순위 자동 계산
- [x] `cidrhost()`로 NAT 소스 네트워크 동적 유도
- [x] `moved {}` 블록으로 state 무중단 마이그레이션

**Packer + Ansible — VyOS 템플릿 자동화**
- [x] `proxmox-iso` builder: ISO → VM → template 변환
- [x] `boot_command`로 `install image` 대화형 자동 응답
- [x] `build_ip` 고정 IP + `ssh_host`로 guest-agent 없이 SSH
- [x] Ansible: hostname, timezone, DNS, qemu-guest-agent 설치/검증
- [x] DHCP 리셋으로 build_ip 잔류 방지

</details>

<details>
<summary>Phase 5: K8s HA 클러스터 + Cilium BGP</summary>

**Ubuntu 템플릿 자동화**
- [x] Packer autoinstall + Ansible (containerd, kubeadm 사전 설치)
- [x] cloud-init으로 정적 IP / SSH key 주입

**K8s 클러스터 (kubeadm + stacked etcd)**
- [x] 3 Control Plane + 3 Worker 배포
- [x] kube-vip ARP + k8s lease HA
- [x] kube-vip.conf (노드 IP 서버) 재부팅 안전성 확보

**Cilium eBPF**
- [x] kube-proxy 완전 대체
- [x] Native routing + BPF masquerade
- [x] BGP Control Plane → VyOS 피어링 (AS 65000 ↔ 65001)
- [x] 6/6 노드 Pod CIDR BGP 광고 확인

</details>
