# Homelab
<!-- toc -->

- [Todo](#todo)
  - [Phase0](#phase0)
  - [Phase1](#phase1)
  - [Phase2](#phase2)
  - [Phase3](#phase3)

<!-- tocstop -->

## 네트워크 토폴로지
```mermaid
flowchart TD
    %% 노드 스타일 정의
    classDef isp fill:#f39c12,stroke:#e67e22,stroke-width:2px,color:#fff;
    classDef switch fill:#34495e,stroke:#2c3e50,stroke-width:2px,color:#fff;
    classDef desktop fill:#7f8c8d,stroke:#34495e,stroke-width:2px,color:#fff;
    classDef portAccess fill:#2ecc71,stroke:#27ae60,stroke-width:2px,color:#fff;
    classDef portTrunk fill:#3498db,stroke:#2980b9,stroke-width:2px,color:#fff;
    classDef pve fill:#9b59b6,stroke:#8e44ad,stroke-width:2px,color:#fff;

    subgraph External ["External Network"]
        ISP["통신사 공유기 (ISP Router)\nGW: 192.168.219.1\nNAT + DHCP + WiFi AP"]:::isp
    end

    subgraph Switch ["MikroTik CRS310-8G+2S+"]
        Bridge["bridgeLocal\n(VLAN Filtering: ON)"]:::switch

        Port1["ether1\n(Uplink)"]:::portAccess
        Port2["ether2\n(Desktop)"]:::portAccess
        Port3["ether3\n(Trunk: pve-node1)"]:::portTrunk
        Port4["ether4\n(Trunk: pve-node2)"]:::portTrunk
        Port5["ether5\n(Trunk: pve-node3)"]:::portTrunk

        Bridge --- Port1
        Bridge --- Port2
        Bridge --- Port3
        Bridge --- Port4
        Bridge --- Port5
    end

    ISP <==>|VLAN 1 Untagged| Port1
    Port2 <==>|VLAN 1 Untagged| PC["Desktop PC"]:::desktop

    Port3 <==>|Trunk: 1, 10, 20, 30| Node1["pve-node1 (Lenovo)\nvmbr0 vlan-aware"]:::pve
    Port4 <==>|Trunk: 1, 10, 20, 30| Node2["pve-node2 (Dell)\nvmbr0 vlan-aware"]:::pve
    Port5 <==>|Trunk: 1, 10, 20, 30| Node3["pve-node3 (Dell)\nvmbr0 vlan-aware"]:::pve
```

## Todo
### Phase0
- [x] VyOS Rolling generic ISO에 cloud-init 부재 확인
- [x] Default apt repo 비활성 상태에서 외부 repo 일회성 활용
- [x] qemu-guest-agent 설치로 PVE → guest IP 자동 발견 가능
- [x] Bootstrap config로 clone 후 즉시 SSH 도달 가능
- [x] Template lock + cloud-init drive 부착
- [x] Clone 검증 (998)으로 모든 흐름 통과 확인

### Phase1
- [x] PVE API 토큰 (terraform@pve!provisioner) 발급
- [x] Terraform Level 2.5 평면 구조 빌드
- [x] bpg/proxmox provider 0.66 설치 + 인증 동작
- [x] Template clone 첫 사이클 (apply 0 error)
- [x] Guest agent 통한 IP 자동 발견 (ipv4_addresses output)
- [x] External SSH 도달성 검증
- [x] VM 안에서 외부 ping 도달 (vlan1 default route 통해)

### Phase2
- [x] Hostname: vyos-rtr-1
- [x] vlan10/20/30 sub-interfaces (.252 IPs, descriptions)
- [x] NAT rules 100/110/120 (vlan10/20/30 → eth0 masquerade)
- [x] Firewall state-policy (set 명령 정상 박힘)
- [x] Routing: connected vlan10/20/30 + static default
- [x] External SSH 여전히 가능 (vlan1 DHCP IP 유지 — 디버깅 fallback)

### Phase3
- [x] Master/Backup 정확히 분리 (priority 200 > 100)
- [x] VRID matching (rtr-1과 rtr-2의 VRID 10/20/30이 정확히 매칭 → 같은 VRRP group으로 인식)
- [x] Last Transition이 1분대 — 가장 최근 apply에서 시작됐다는 증거
- [x] Sync-group ALL 동작 중 (3 group 모두 동일 상태)
