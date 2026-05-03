# Terraform 모듈화 리팩토링 완료 보고서

**작업일**: 2026-05-03  
**작업 범위**: 평면(flat) 구조 → 재사용 가능한 모듈 구조 전환  
**결과**: `terraform plan` 기준 **0 to add / 0 to change / 0 to destroy** (인프라 무변경)

---

## 1. 변경 전 구조 (Before)

```
homelab-iac/
├── versions.tf
├── providers.tf
├── variables.tf        # 193줄 — 모든 변수 혼재
├── locals.tf           # 135줄 — IP 추출 + VRRP 블록 + 설정 스크립트 2개
├── vyos.tf             # 206줄 — VM 2개 + null_resource 2개 직접 정의
├── outputs.tf          # 99줄
└── modules/
    └── .gitkeep        # 비어있음
```

**문제점**
- rtr-1과 rtr-2 리소스가 대부분 동일한데 별도로 중복 선언
- VRRP 설정 스크립트가 locals.tf에 인라인으로 하드코딩
- 새 라우터를 추가하려면 VM/null_resource/outputs를 모두 복사해야 함
- k8s-cluster, tailscale-gw 추가 시 루트가 비대해짐

---

## 2. 변경 후 구조 (After)

```
homelab-iac/
├── versions.tf                         # 변경 없음
├── providers.tf                        # 변경 없음
├── variables.tf                        # 변경 없음 (루트 변수 유지)
├── locals.tf                           # 3줄 — tags, datastore만
├── main.tf                  ★ NEW      # 모듈 호출 2개 (rtr-1, rtr-2)
├── moved.tf                 ★ NEW      # state 경로 마이그레이션 선언
├── outputs.tf                          # 모듈 output 참조로 교체
├── vyos.tf                             # 리소스 제거, 리다이렉션 주석만 남김
│
└── modules/
    ├── vyos-router/          ★ NEW     # 재사용 가능한 VyOS 라우터 모듈
    │   ├── versions.tf                 # bpg/proxmox + hashicorp/null 선언
    │   ├── variables.tf                # 모듈 입력 변수 (role, vlan IPs, VRRP 등)
    │   ├── locals.tf                   # bootstrap IP 추출 + 설정 스크립트 생성
    │   ├── main.tf                     # proxmox_virtual_environment_vm + null_resource
    │   └── outputs.tf                  # vm_id, bootstrap_ip, vlan IPs 등
    │
    ├── k8s-cluster/          ★ STUB    # 향후: K8s VM 클러스터
    │   └── README.md
    │
    └── lxc-container/        ★ STUB   # 향후: tailscale-gw LXC
        └── README.md
```

---

## 3. 핵심 변경 사항

### 3-1. `modules/vyos-router` 모듈

VyOS 라우터 인스턴스 1개를 완전히 캡슐화합니다.

| 파일 | 역할 |
|------|------|
| `variables.tf` | vm_id, node_name, role (master/backup), vlan IPs, VRRP 파라미터 등 |
| `locals.tf` | guest agent에서 bootstrap IP 추출, NAT 네트워크 주소 계산, 설정 스크립트 동적 생성 |
| `main.tf` | `proxmox_virtual_environment_vm.this` + `null_resource.provision` |
| `outputs.tf` | vm_id, node_name, bootstrap_ip, ssh_command, vlan IPs, provisioned |
| `versions.tf` | non-hashicorp 프로바이더(bpg/proxmox) 명시 선언 (모듈 필수) |

**주요 개선점**:
- `role = "master" | "backup"` 변수로 VRRP 우선순위 자동 계산
- NAT 규칙의 소스 네트워크를 VLAN IP에서 동적으로 유도 (`cidrhost()`)
  - 기존: `192.168.10.0/24` 하드코딩
  - 변경: `cidrhost(var.vlan10_ip, 0)` 계산 → 서브넷 변경 시 자동 반영

### 3-2. `main.tf` (루트)

```hcl
module "vyos_rtr_1" {
  source = "./modules/vyos-router"
  role   = "master"
  ...
}

module "vyos_rtr_2" {
  source = "./modules/vyos-router"
  role   = "backup"
  ...
}
```

같은 모듈을 역할만 바꿔 두 번 호출합니다.

### 3-3. `moved.tf` — 무중단 state 마이그레이션

`terraform state mv` 없이 기존 state 경로를 새 모듈 경로로 자동 매핑합니다.

```hcl
moved {
  from = proxmox_virtual_environment_vm.vyos_rtr_1
  to   = module.vyos_rtr_1.proxmox_virtual_environment_vm.this
}
# ... 4개 리소스 전체
```

**효과**: `terraform apply` 한 번으로 state가 조용히 이관됩니다. VM 재생성 없음.

---

## 4. 검증 결과

```
$ terraform validate
Success! The configuration is valid.

$ terraform plan
Plan: 0 to add, 0 to change, 0 to destroy.
```

- `proxmox_virtual_environment_vm.vyos_rtr_1` → `module.vyos_rtr_1.proxmox_virtual_environment_vm.this` ✅ moved
- `null_resource.vyos_rtr_1_provision`         → `module.vyos_rtr_1.null_resource.provision`               ✅ moved
- `proxmox_virtual_environment_vm.vyos_rtr_2` → `module.vyos_rtr_2.proxmox_virtual_environment_vm.this` ✅ moved
- `null_resource.vyos_rtr_2_provision`         → `module.vyos_rtr_2.null_resource.provision`               ✅ moved

출력값 변경: `vyos_rtr_1_ipv4_addresses`에 VRRP VIP(192.168.10.1 등)가 추가 노출됩니다.
이는 VRRP가 활성화된 현재 VM 상태를 guest agent가 정확히 반영한 것으로, 의도된 동작입니다.

---

## 5. 마이그레이션 절차

기존 인프라가 운영 중인 상태에서 적용하는 방법입니다.

```bash
# 1. 프로바이더 및 모듈 초기화
terraform init

# 2. plan으로 moved 블록만 처리되는지 확인
terraform plan

# 3. state 마이그레이션 적용 (VM 재생성 없음)
terraform apply

# 4. moved.tf는 apply 완료 후 삭제해도 무방
#    (남겨둬도 idempotent하게 동작함)
```

---

## 6. 향후 확장 계획

### Phase 4: k8s-cluster (`modules/k8s-cluster/`)

Kubernetes 클러스터를 Proxmox VM으로 배포하는 모듈.

```hcl
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

  control_plane_count = 3
  worker_count        = 3
  template_id         = var.ubuntu_template_id
  vlan_id             = 20
  default_gateway     = module.vyos_rtr_1.vlan20_ip  # VRRP VIP 참조
}
```

| 항목 | 계획 |
|------|------|
| VM ID 범위 | 211~213 (control-plane), 221~223 (worker) |
| OS 템플릿 | Ubuntu 24.04 cloud-init |
| VLAN | vlan20 (k8s-svc, 192.168.20.0/24) |
| Default GW | 192.168.20.1 (VRRP VIP) |
| 노드 배치 | pve-node1/2/3 분산 |

### Phase 5: tailscale-gw (`modules/lxc-container/`)

Proxmox LXC 컨테이너로 배포하는 범용 모듈. 첫 소비자는 Tailscale subnet router.

```hcl
module "tailscale_gw" {
  source = "./modules/lxc-container"

  ct_id    = 310
  name     = "tailscale-gw"
  template = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  vlan_id  = 10
  gateway  = module.vyos_rtr_1.vlan10_ip
}
```

| 항목 | 계획 |
|------|------|
| Container ID | 310 |
| VLAN | vlan10 (mgmt, 192.168.10.0/24) |
| 역할 | Tailscale subnet router (VPN → 내부 VLAN 전달) |
| 광고 경로 | 192.168.10.0/24, 192.168.20.0/24, 192.168.30.0/24 |

---

## 7. 모듈 의존 관계

```
providers.tf / versions.tf
        │
        ▼
main.tf (루트 진입점)
   ├── module.vyos_rtr_1  ──► modules/vyos-router/
   ├── module.vyos_rtr_2  ──► modules/vyos-router/
   │
   │   [Phase 4 추가 예정]
   ├── module.k8s_cluster ──► modules/k8s-cluster/
   │       └── depends_on: vyos_rtr_1, vyos_rtr_2 (default GW)
   │
   │   [Phase 5 추가 예정]
   └── module.tailscale_gw ─► modules/lxc-container/
           └── depends_on: vyos_rtr_1 (default GW)
```

---

## 8. 파일별 변경 요약

| 파일 | 상태 | 내용 |
|------|------|------|
| `main.tf` | ✅ 신규 | module 호출 2개 |
| `moved.tf` | ✅ 신규 | state 경로 재매핑 4개 |
| `locals.tf` | ✏️ 수정 | 135줄 → 3줄 (tags, datastore만 유지) |
| `outputs.tf` | ✏️ 수정 | 직접 참조 → 모듈 output 참조 |
| `vyos.tf` | ✏️ 수정 | 리소스 제거, 리다이렉션 주석 |
| `terraform.tfvars` | ✏️ 수정 | config_version 값 추가 (provisioner 재실행 방지) |
| `modules/vyos-router/*` | ✅ 신규 | 모듈 구현 5개 파일 |
| `modules/k8s-cluster/README.md` | ✅ 신규 | 설계 스텁 |
| `modules/lxc-container/README.md` | ✅ 신규 | 설계 스텁 |
