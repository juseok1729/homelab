# Homelab
<!-- toc -->

- [Todo](#todo)
  - [Phase0](#phase0)
  - [Phase1](#phase1)
  - [Phase2](#phase2)
  - [Phase3](#phase3)
  - [Phase4](#phase4)

<!-- tocstop -->

## VM 배치 토폴로지
```mermaid
flowchart TB
    subgraph Node1["🖥️ Node1 · pve-node1 / Lenovo m70q gen6 · 32G / 14c"]
        direction TB
        VY1["🌐 vyos-rtr-1<br/>2c · 2G · 10G<br/>📌 VRRP master"]
        CP1["🔵 k8s-cp1<br/>2c · 4G · 30G<br/>📌 P-core pinned"]
        W1["🟢 k8s-w1<br/>6c · 12G · 80G<br/>메인 워커"]
        TS["🟣 tailscale-gw<br/>1c · 0.5G · 4G<br/>LXC subnet router"]
    end

    subgraph Node2["🖥️ Node2 · pve-node2 / Dell 7070 micro · 16G / 6c"]
        direction TB
        VY2["🌐 vyos-rtr-2<br/>1c · 1G · 10G<br/>📌 VRRP backup"]
        CP2["🔵 k8s-cp2<br/>2c · 4G · 30G"]
        W2["🟢 k8s-w2<br/>3c · 8G · 60G"]
    end

    subgraph Node3["🖥️ Node3 · pve-node3 / Dell 7070 micro · 16G / 6c"]
        direction TB
        CP3["🔵 k8s-cp3<br/>2c · 4G · 30G"]
        W3["🟢 k8s-w3<br/>3c · 8G · 60G"]
    end

    Node1 ~~~ Node2
    Node2 ~~~ Node3

    classDef router fill:#FAEEDA,stroke:#854F0B,color:#412402
    classDef cp fill:#E6F1FB,stroke:#185FA5,color:#042C53
    classDef worker fill:#E1F5EE,stroke:#0F6E56,color:#04342C
    classDef gw fill:#EEEDFE,stroke:#534AB7,color:#26215C

    class VY1,VY2 router
    class CP1,CP2,CP3 cp
    class W1,W2,W3 worker
    class TS gw
```

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
### Phase0: VyOS Template 수동 제작
- [x] VyOS Rolling generic ISO에 cloud-init 부재 확인
- [x] Default apt repo 비활성 상태에서 외부 repo 일회성 활용
- [x] qemu-guest-agent 설치로 PVE → guest IP 자동 발견 가능
- [x] Bootstrap config로 clone 후 즉시 SSH 도달 가능
- [x] Template lock + cloud-init drive 부착
- [x] Clone 검증 (998)으로 모든 흐름 통과 확인

### Phase1: Terraform 첫 번째 VM 프로비저닝
- [x] PVE API 토큰 (terraform@pve!provisioner) 발급
- [x] Terraform Level 2.5 평면 구조 빌드
- [x] bpg/proxmox provider 0.66 설치 + 인증 동작
- [x] Template clone 첫 사이클 (apply 0 error)
- [x] Guest agent 통한 IP 자동 발견 (ipv4_addresses output)
- [x] External SSH 도달성 검증
- [x] VM 안에서 외부 ping 도달 (vlan1 default route 통해)

### Phase2: vyos-rtr-1 네트워크 설정
- [x] Hostname: vyos-rtr-1
- [x] vlan10/20/30 sub-interfaces (.252 IPs, descriptions)
- [x] NAT rules 100/110/120 (vlan10/20/30 → eth0 masquerade)
- [x] Firewall state-policy (set 명령 정상 박힘)
- [x] Routing: connected vlan10/20/30 + static default
- [x] External SSH 여전히 가능 (vlan1 DHCP IP 유지 — 디버깅 fallback)

### Phase3: VRRP HA 이중화 구성
- [x] Master/Backup 정확히 분리 (priority 200 > 100)
- [x] VRID matching (rtr-1과 rtr-2의 VRID 10/20/30이 정확히 매칭 → 같은 VRRP group으로 인식)
- [x] Last Transition이 1분대 — 가장 최근 apply에서 시작됐다는 증거
- [x] Sync-group ALL 동작 중 (3 group 모두 동일 상태)

### Phase4: IaC 리팩토링 및 Template 자동화
#### Terraform 모듈화
- [x] 평면(flat) 구조 → `modules/vyos-router/` 재사용 모듈 분리
- [x] `role = "master" | "backup"` 변수로 VRRP 우선순위 자동 계산
- [x] NAT 소스 네트워크 `cidrhost()` 동적 유도 (하드코딩 제거)
- [x] `moved {}` 블록으로 기존 state 무중단 마이그레이션 (`terraform plan`: 0 to add/change/destroy)
- [x] `modules/k8s-cluster/`, `modules/lxc-container/` 미래 모듈 스텁 생성
- [x] 완료 보고서 `docs/REFACTORING.md` 작성

#### Packer + Ansible — VyOS 템플릿 자동화
- [x] `packer/vyos-template/vyos-template.pkr.hcl` 작성
  - [x] `proxmox-iso` builder: ISO 다운로드 → VM 생성 → 부팅 → template 변환
  - [x] `boot_command`: `install image` 대화형 프롬프트 자동 응답 (VNC 키 주입)
  - [x] `boot = "order=scsi0;ide2"`: 설치 전 CDROM 폴백, 설치 후 디스크 GRUB 우선 부팅
  - [x] `build_ip` 고정 IP + `ssh_host` 지정으로 qemu-guest-agent 없이 SSH 접속
  - [x] `cloud_init_storage_pool`: PVE 호환용 cloud-init drive 자동 추가
  - [x] `nohup` 기반 DHCP 리셋 → template에 build_ip 잔류 방지
- [x] `ansible/vyos-template/playbook.yml` 작성
  - [x] VyOS 기본 설정 (hostname, timezone, DNS) via vbash
  - [x] Debian Bookworm repo 임시 추가 → qemu-guest-agent 설치 → repo 즉시 제거
  - [x] 검증 tasks: agent 상태, 잔존 repo, 패키지 설치 확인
- [x] Packer + Ansible 빌드 실행 완료 (Ansible `ok=14 changed=7 failed=0`)
