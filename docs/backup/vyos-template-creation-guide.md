# Homelab Infrastructure — Phase 2 완료 보고서

> 본 문서는 다음 Claude 세션에서 작업을 이어갈 때 컨텍스트를 빠르게
> 복원하기 위한 스냅샷입니다. 작업 디렉토리, 현재 상태, 다음 단계를
> 한 번에 파악할 수 있도록 정리.

---

## 📊 현재 인프라 상태

### Layer 1 — 물리/L2 (완료)

```
MikroTik CRS310 — L2 switch only
  vlan-filtering=yes
  vlan10/20/30 SVI 모두 제거 (L3는 VyOS에 위임)
  vlan1: 192.168.219.2/24 (mgmt fallback)
  vlan10: 192.168.10.2/24 (예약 — VyOS 배포 후 활성화)
  ether1: vlan1 access (공유기 uplink, hardening 적용)
  ether2: vlan1 access (데스크탑 idle, hardening 적용)
  ether3-5: trunk (vlan1u + 10/20/30t)
  미사용 포트(ether6-8, sfp-sfpplus1-2) bridge에서 제거
  default route: 192.168.219.1 (단순성 유지)
```

### Layer 2 — 하이퍼바이저 (완료)

```
PVE 3-node:
  pve-node1 (192.168.219.11): m70q gen6, 32GB, 14c, 783GB lvmthin
  pve-node2 (192.168.219.12): 7070 micro, 16GB, 6c, 192GB lvmthin
  pve-node3 (192.168.219.13): 7070 micro, 16GB, 6c, 192GB lvmthin

각 노드 vmbr0:
  vlan-filtering=1
  nic0: PVID 1 + vid 2-4094 (trunk)
  vmbr0 self: PVID 1 (호스트 mgmt vlan1 고정 — 의도)

Storage (3노드 동일):
  local: dir
  local-lvm: lvmthin
```

### Layer 3 — VyOS template (완료)

```
PVE node1의 VM 9000 = vyos-template (read-only)
  VyOS 2026.04.13-0034-rolling generic
  Bootstrap config:
    - eth0 DHCP
    - SSH active (port 22, 0.0.0.0)
    - hostname: vyos-template
    - time-zone: Asia/Seoul
    - name-server: 1.1.1.1, 8.8.8.8
    - static default route 0.0.0.0/0 → 192.168.219.1
  Extra:
    - qemu-guest-agent installed (Debian repo 일회성, 즉시 제거)
  Disk: 4GB (base-9000-disk-0, read-only)
  Cloud-init drive: ide2 attached (Terraform 호환용, VyOS는 안 읽음)

상세 작성 절차 + 함정 7개:
→ vyos-template-creation-guide.md
```

### Layer 4 — Terraform Phase 2 (완료)

```
디렉토리: ~/Projects/homelab/homelab-iac
구조: Level 2.5 (평면 + 진화 대비)

파일:
  versions.tf        # Terraform 1.5.7, bpg/proxmox ~> 0.66
  providers.tf       # API token only (ssh block 없음)
  variables.tf       # 변수 선언
  locals.tf          # vm_tags_router, datastore="local-lvm"
  vyos.tf            # vyos-rtr-1 정의
  outputs.tf         # bootstrap_ip, ssh_command 등
  terraform.tfvars   # gitignored, API token secret
  .gitignore
  modules/.gitkeep   # 진화 대비

배포 결과:
  vyos-rtr-1 (VM 110) on pve-node1
  bootstrap_ip: 192.168.219.106 (DHCP)
  MAC: bc:24:11:ef:57:73
  SSH: vyos@192.168.219.106 (password: vyos)
  qemu-guest-agent: active
  외부 ping 도달 OK
```

### Layer 5+ — 미진행

```
⏸️ Phase 3: vyos-rtr-1에 production config 주입
   - vlan10/20/30 sub-interface 생성
   - Static route, firewall basic
   - VRRP 단독 시작 (master 우선순위)
   - SSH key 인증 전환

⏸️ Phase 4: vyos-rtr-2 추가 + VRRP HA 활성

⏸️ Phase 5: 검증 (vlan20에서 .10.2 도달성 등)

⏸️ Phase 6: K8s VM 6대 (CP3 + W3) Terraform 부트스트랩
   - kubeadm으로 stacked etcd HA
   - Cilium eBPF (kube-proxy 대체)
   - kube-vip (apiserver HA VIP)

⏸️ Phase 7+: Gateway API, observability, NanoClaw 마이그레이션
```

---

## 🎯 다음 세션 시작점 — Phase 3

### Phase 3 목표

vyos-rtr-1 (현재 vlan1 DHCP에 떠 있는 상태) 에 production config 주입.

```
[Phase 3 산출물]
- vlan10 interface (.252/24) — vyos-rtr-1.eth0.10
- vlan20 interface (.252/24) — vyos-rtr-1.eth0.20
- vlan30 interface (.252/24) — vyos-rtr-1.eth0.30
- Static route to upstream (0.0.0.0/0 → 192.168.219.1)
- NAT (vlan10/20/30 → vlan1 outbound masquerade)
- 기본 firewall (vlan10/20/30 inbound to vyos: SSH 허용 등)
- Hostname → vyos-rtr-1
- vyos 사용자 password 변경 + SSH key 인증 추가

[Phase 3에서 의도적으로 제외]
- VRRP는 vyos-rtr-2가 있어야 의미. 일단 단독 라우터로 동작.
  Phase 4에서 VRRP 활성화.
```

### Phase 3 코드 패턴 (예고)

```hcl
# vyos.tf에 추가
resource "null_resource" "vyos_rtr_1_provision" {
  depends_on = [proxmox_virtual_environment_vm.vyos_rtr_1]
  
  triggers = {
    config_version = "v1"  # 변경 시 재실행 트리거
  }
  
  connection {
    type     = "ssh"
    host     = local.vyos_rtr_1_ip   # bootstrap_ip
    user     = "vyos"
    password = "vyos"
    timeout  = "5m"
  }
  
  provisioner "remote-exec" {
    inline = [
      # VyOS configure mode wrapping
      "source /opt/vyatta/etc/functions/script-template",
      "configure",
      
      # Hostname
      "set system host-name 'vyos-rtr-1'",
      
      # vlan10/20/30 sub-interfaces
      "set interfaces ethernet eth0 vif 10 address '192.168.10.252/24'",
      "set interfaces ethernet eth0 vif 20 address '192.168.20.252/24'",
      "set interfaces ethernet eth0 vif 30 address '192.168.30.252/24'",
      
      # NAT (vlan10/20/30 outbound)
      "set nat source rule 100 outbound-interface 'eth0'",
      "set nat source rule 100 source address '192.168.10.0/24'",
      "set nat source rule 100 translation address 'masquerade'",
      # ... rule 110 (vlan20), 120 (vlan30)
      
      # Commit + Save
      "commit",
      "save",
      "exit",
    ]
  }
}
```

### Phase 3 함정 미리 짚기

1. **VyOS의 `configure` 모드는 인터랙티브 shell 가정** — `script-template`로 wrap 필요
2. **첫 commit 후 인터페이스 IP가 vlan10으로 옮겨가면 SSH 끊김** — vlan1 IP 유지하는 트릭 필요 (eth0 자체는 IP 없이 trunk로 두고, vif만 사용)
3. **`null_resource` triggers**: 매 plan마다 재실행되지 않도록 trigger 신중 설계
4. **idempotency**: `set` 명령은 멱등이지만 commit 실패 시 부분 적용 가능 — rollback 전략 필요
5. **공유기의 DHCP lease**: vlan1 IP를 더 이상 안 쓰면 lease 회수돼야 깔끔. eth0를 명시 disable 또는 cleanup config.

---

## 📝 학습 도큐먼트 보관 위치

```
~/Projects/homelab/homelab-iac/                # Terraform 코드
~/Documents/homelab-docs/                       # (권장) 가이드 모음
  ├── vyos-template-creation-guide.md          # 본 가이드 1
  ├── terraform-5-levels-learning-prompt.md    # 학습 프롬프트
  └── phase2-completion-report.md              # 본 문서
```

---

## 🔑 다음 세션 시작 시 컨텍스트 복원 방법

새 Claude 세션에서:

1. 본 문서 + `vyos-template-creation-guide.md` 첨부
2. 첫 메시지:

```
Homelab K8s 클러스터 구축 중. Phase 2까지 완료, Phase 3 진입.
첨부한 phase2-completion-report.md로 컨텍스트 복원하고
Phase 3 (vyos-rtr-1 production config 주입) 시작.

특히 Phase 3 함정 5가지를 의식하면서 idempotent한 코드로 가자.
```

이러면 자연스럽게 이어집니다.
