# Homelab IaC 아키텍처 학습 가이드

이 문서는 코드베이스를 스스로 이해하고 확장할 수 있도록
전체 구조와 설계 의도를 설명합니다.

---

## 전체 구조

```
homelab-iac/
├── main.tf              ← 루트 모듈 (리소스 조합)
├── variables.tf         ← 입력 변수 선언
├── outputs.tf           ← 출력값 정의
├── locals.tf            ← 공통 로컬 값
├── versions.tf          ← provider 버전 고정
├── terraform.tfvars     ← 실제 secret 값 (gitignore)
│
├── modules/             ← 재사용 가능한 Terraform 모듈
│   ├── vyos-router/     ← VyOS HA 라우터
│   ├── k8s-cluster/     ← K8s 클러스터 (부모 모듈)
│   │   ├── k8s-vm/      ← VM 생성 (서브모듈)
│   │   └── k8s-bootstrap/  ← Ansible 실행 (서브모듈)
│   └── lxc-container/   ← (예정) LXC 컨테이너
│
├── packer/              ← VM 템플릿 빌드
│   ├── vyos-template/   ← VyOS 9000번 템플릿
│   └── ubuntu-template/ ← Ubuntu 9001번 템플릿
│
└── ansible/             ← VM 프로비저닝
    ├── vyos-template/   ← VyOS 템플릿 후처리
    ├── ubuntu-template/ ← Ubuntu 템플릿 후처리
    └── k8s-bootstrap/   ← K8s 클러스터 부트스트랩
        └── roles/
            ├── common/          ← containerd, sysctl
            ├── kube-vip/        ← VIP 관리 pod
            ├── kubeadm-init/    ← 첫 번째 CP 초기화
            ├── kubeadm-join-cp/ ← CP 추가 조인
            ├── kubeadm-join-worker/ ← worker 조인
            └── cilium/          ← CNI 설치
```

---

## 레이어별 설명

### Layer 0: 물리 / 스위치 (수동)

MikroTik CRS310 스위치에 VLAN 필터링을 수동으로 설정합니다.

```
VLAN1  (untagged): 관리망 192.168.219.x (ISP 라우터와 동일 세그먼트)
VLAN10 (tagged):   mgmt   192.168.10.0/24
VLAN20 (tagged):   k8s    192.168.20.0/24
VLAN30 (tagged):   storage 192.168.30.0/24
```

### Layer 1: Proxmox VE (수동 설치)

3대의 미니PC에 PVE를 직접 설치합니다.
- pve-node1: M70q Gen 6 (32GB/14c)
- pve-node2/3: OptiPlex 7070 Micro (16GB/6c)

모든 노드에 `nic-hang-fix.service`가 설치되어 Intel I219-LM NIC 행업을 방지합니다.
→ 참고: `docs/nic-hang-fix.md`

### Layer 2: VM 템플릿 (Packer)

`packer build`로 PVE에 템플릿 VM을 생성합니다.

```
VyOS  → VM ID 9000 (packer/vyos-template/)
Ubuntu → VM ID 9001 (packer/ubuntu-template/)
```

**VyOS 템플릿 빌드 흐름:**
1. Packer가 VNC로 ISO 부팅 및 `install image` 대화형 응답
2. 고정 IP로 SSH 접속 후 Ansible 실행 (패키지, qemu-agent)
3. Shell provisioner: config.boot를 DHCP로 초기화
4. post-processor: serial0, cloud-init 드라이브 추가

**Ubuntu 템플릿 빌드 흐름:**
1. Packer가 autoinstall(cloud-init)로 무인 설치
2. Ansible 실행: containerd, kubeadm, kubelet, kubectl 설치
3. Shell provisioner: cloud-init 상태 초기화

### Layer 3: 라우터 프로비저닝 (Terraform + SSH)

```hcl
# main.tf
module "vyos_rtr_1" { source = "./modules/vyos-router" }
module "vyos_rtr_2" { source = "./modules/vyos-router" }
```

**vyos-router 모듈 내부:**
1. `proxmox_virtual_environment_vm`: 템플릿 clone → VM 생성
2. `null_resource.provision`: SSH → vbash 스크립트 실행

**구성 내용:**
- VLAN 서브 인터페이스 (eth0.10/20/30)
- NAT masquerade (vlan→인터넷)
- NAT 제외 (vlan→관리망 192.168.219.x, 직접 라우팅)
- VRRP HA (vrid 10/20/30, sync-group ALL)
- BGP (선택, `vyos_bgp_enabled=true` 시 활성화)

**VRRP 동작:**
```
vyos-rtr-1 (master, priority 200) → VRRP VIP .1 보유
vyos-rtr-2 (backup, priority 100) → 대기 중
master 장애 시 → backup이 .1 인계
```

### Layer 4: K8s 클러스터 (Terraform + Ansible)

```hcl
# main.tf
module "k8s_cluster" { source = "./modules/k8s-cluster" }
```

**k8s-cluster 모듈 구조:**
```
k8s-cluster/
  locals.tf      ← VM 정의 (IP, VM ID, 노드)
  main.tf        ← k8s-vm × 6 + k8s-bootstrap 호출
  k8s-vm/        ← proxmox VM + cloud-init
  k8s-bootstrap/ ← inventory 생성 + Ansible 실행
```

**VM 배치:**
```
pve-node1: k8s-cp1 (211), k8s-w1 (221, 4c/8GB)
pve-node2: k8s-cp2 (212), k8s-w2 (222)
pve-node3: k8s-cp3 (213), k8s-w3 (223)
```

**cloud-init으로 주입되는 것:**
- 정적 IP (192.168.20.11\~13, 21\~23)
- SSH 공개키 (`ansible` 유저)
- DNS, 기본 게이트웨이

**k8s-bootstrap 실행 순서:**
1. SSH 접근 가능 여부 확인 (wait_for_nodes)
2. Ansible playbook 실행

---

## Ansible Bootstrap 흐름

```
Play 1: 모든 노드 (common role)
  → swap 비활성화
  → kernel modules (overlay, br_netfilter)
  → sysctl (ip_forward, bridge-nf-call)
  → containerd 재설정 (SystemdCgroup=true, sandbox_image 명시)
  → kubelet 활성화

Play 2: k8s-cp1 (kube-vip + kubeadm-init)
  → kube-vip 이미지 pre-pull
  → kube-vip manifest 배치
  → ip addr add VIP (bootstrap용 임시 VIP)
  → kubeadm init --upload-certs
  → kube-vip.conf 생성 (server=노드IP)
  → kube-vip pod 재시작

Play 3: k8s-cp2/3 (kube-vip + kubeadm-join-cp, serial)
  → kube-vip manifest 배치
  → kubeadm join --control-plane
  → kube-vip.conf 생성

Play 4: k8s-w1/2/3 (kubeadm-join-worker)
  → kubeadm join

Play 5: k8s-cp1 (cilium)
  → helm install cilium (kube-proxy 대체, BGP 활성화)
  → CiliumBGPPeeringPolicy 적용
```

---

## 네트워크 토폴로지

```
인터넷
  │
ISP 라우터 (192.168.219.1)
  │
MikroTik 스위치
  ├─ ether1: ISP (VLAN1 untagged)
  ├─ ether2: 개발 Mac (VLAN1 untagged)
  └─ ether3~5: PVE 노드 (VLAN1u + VLAN10/20/30 tagged)
         │
    vmbr0 (VLAN-aware bridge)
         │
    VyOS VRRP 쌍
    ├─ eth0.10: 192.168.10.252/253 → VIP .1 (mgmt)
    ├─ eth0.20: 192.168.20.252/253 → VIP .1 (k8s GW)
    └─ eth0.30: 192.168.30.252/253 → VIP .1 (storage)
         │
    K8s 클러스터 (VLAN20)
    ├─ k8s-cp1: 192.168.20.11
    ├─ k8s-cp2: 192.168.20.12
    ├─ k8s-cp3: 192.168.20.13
    ├─ k8s-w1:  192.168.20.21
    ├─ k8s-w2:  192.168.20.22
    └─ k8s-w3:  192.168.20.23
    kube-vip VIP: 192.168.20.10 (API server)
```

**Mac에서 K8s 접근:**
Mac은 192.168.219.x 대역이므로 vlan20에 직접 접근 불가.
VyOS를 경유하는 정적 라우팅이 필요합니다:
```bash
sudo route -n add -net 192.168.20.0/24 192.168.219.106
```
재부팅 후 유지하려면 launchd 서비스 등록 필요.

---

## BGP 피어링 구조

```
VyOS (AS 65000)
  └─ BGP neighbor: k8s-cp1~3, w1~3 (all nodes)

K8s Cilium (AS 65001)
  └─ BGP peer: 192.168.20.1 (VyOS VRRP VIP)
  └─ exportPodCIDR: true → 각 노드의 Pod CIDR을 VyOS에 광고
```

**효과:**
- VyOS가 Pod CIDR 라우트를 학습
- 외부에서 Pod IP로 직접 접근 가능

**활성화 방법:**
```hcl
# terraform.tfvars
vyos_bgp_enabled          = true
vyos_rtr_1_config_version = "v6"
vyos_rtr_2_config_version = "v4"
```

---

## 주요 변수와 IP 대역 요약

| 용도 | IP/CIDR | 변수명 |
|---|---|---|
| ISP 관리망 | 192.168.219.0/24 | (고정) |
| VyOS master eth0 | 192.168.219.106 | DHCP |
| VLAN20 게이트웨이 | 192.168.20.1 | `vrrp_vip_vlan20` |
| k8s API VIP | 192.168.20.10 | `k8s_vip` |
| k8s 노드 대역 | 192.168.20.11~23 | locals.tf |
| Pod CIDR | 10.244.0.0/16 | `k8s_pod_cidr` |
| Service CIDR | 10.96.0.0/12 | `k8s_service_cidr` |

---

## 추가 개발 시 참고사항

### 새 모듈 추가 패턴
기존 `modules/vyos-router/` 구조를 참고합니다:
- `main.tf`: 실제 리소스
- `variables.tf`: 입력값 정의
- `locals.tf`: 계산된 값
- `outputs.tf`: 다른 모듈이 참조할 값
- `versions.tf`: provider 버전

### 재배포 방법
```bash
# VyOS 재설정 (BGP 활성화 등)
vyos_rtr_1_config_version = "vN+1"   # terraform.tfvars
terraform apply -target=module.vyos_rtr_1

# K8s 재배포
terraform destroy -target=module.k8s_cluster
terraform apply

# Ubuntu 템플릿 재빌드
cd packer/ubuntu-template
packer build -var-file=variables.pkrvars.hcl ubuntu-template.pkr.hcl
```

### 디버깅 도움말
```bash
# VyOS 설정 확인
ssh vyos@192.168.219.106
show interfaces
show nat source rules
show bgp summary   # BGP 활성화 후

# K8s 상태
export KUBECONFIG=~/.kube/homelab-config
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl logs kube-vip-k8s-cp1 -n kube-system

# Cilium 상태
kubectl exec -n kube-system ds/cilium -- cilium status
kubectl get CiliumBGPPeeringPolicy
```
