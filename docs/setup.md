# 홈랩 셋업 가이드

이 가이드를 따라가면 VyOS HA 라우터 + K8s HA 클러스터 전체를
처음부터 자동으로 구성할 수 있습니다.

---

## 필수 조건

### 하드웨어

| 항목 | 최소 사양 | 이 프로젝트 기준 |
|---|---|---|
| PVE 노드 | 3대 (HA 구성) | M70q Gen 6 × 1, OptiPlex 7070 × 2 |
| 스위치 | VLAN 지원 | MikroTik CRS310-8G+2S+ |

### 개발 머신에 설치 필요

```bash
# macOS 기준
brew install terraform packer ansible

# 버전 확인
terraform version   # >= 1.5
packer version      # >= 1.10
ansible --version   # >= 2.14
```

### SSH 키 준비

```bash
# 없으면 생성
ssh-keygen -t ed25519 -C "homelab"

# 공개키 확인 (terraform.tfvars에 필요)
cat ~/.ssh/id_ed25519.pub
```

---

## Step 0: 수동 사전 작업

### 0-1. Proxmox VE 설치 (각 노드)

[공식 문서](https://pve.proxmox.com/wiki/Installation)에 따라 설치 후
세 노드를 동일한 PVE 클러스터로 구성합니다.

기본 가정:
- pve-node1: `192.168.219.11` (주 노드, VyOS/K8s 템플릿 보관)
- pve-node2: `192.168.219.12`
- pve-node3: `192.168.219.13`

### 0-2. NIC 행업 방지 설정 (모든 PVE 노드)

Intel I219-LM NIC 행업 버그 방지 — K8s 부트스트랩 중 노드가 다운될 수 있습니다.
→ 상세: `docs/nic-hang-fix.md`

```bash
# 각 PVE 노드에서 실행
ssh root@192.168.219.11

cat > /etc/systemd/system/nic-hang-fix.service << 'EOF'
[Unit]
Description=Disable e1000e offloading to prevent NIC hang
After=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/ethtool -K nic0 tso off gso off gro off rx off tx off
ExecStart=/sbin/ethtool -K vmbr0 tso off gso off gro off rx off tx off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now nic-hang-fix.service
```

### 0-3. MikroTik 스위치 VLAN 설정 (수동)

```
ether1 → ISP 라우터 (VLAN1 untagged)
ether2 → 개발 Mac (VLAN1 untagged)
ether3 → pve-node1 (VLAN1 untagged + VLAN10/20/30 tagged)
ether4 → pve-node2 (VLAN1 untagged + VLAN10/20/30 tagged)
ether5 → pve-node3 (VLAN1 untagged + VLAN10/20/30 tagged)
```

### 0-4. Proxmox API 토큰 생성

PVE 웹 GUI → Datacenter → Permissions → API Tokens:

```
User: terraform@pve (별도 생성 권장)
Token ID: provisioner
Role: PVEAdmin (또는 필요 권한만)
Privilege Separation: 체크 해제
```

생성된 토큰을 저장해 둡니다: `terraform@pve!provisioner=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

---

## Step 1: 저장소 클론

```bash
git clone https://github.com/juseok1729/homelab.git
cd homelab
```

---

## Step 2: 변수 파일 설정

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`를 열어 **필수 항목**을 채웁니다:

```hcl
# ── 필수: Proxmox 인증 ────────────────────────────────────────
pve_api_token = "terraform@pve!provisioner=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# ── 필수: K8s 클러스터 SSH 키 ─────────────────────────────────
# cat ~/.ssh/id_ed25519.pub 결과를 붙여넣기
k8s_ssh_public_key = "ssh-ed25519 AAAA... user@host"

# ── 선택: 기본값과 다른 경우만 수정 ───────────────────────────
# pve_endpoint               = "https://192.168.219.11:8006/"
# pve_node_name              = "pve-node1"
# k8s_ssh_private_key_path   = "~/.ssh/id_ed25519"
# k8s_kubeconfig_output_path = "~/.kube/homelab-config"
```

**변수 전체 목록은 하단 [변수 레퍼런스](#변수-레퍼런스) 참고**

---

## Step 3: VyOS 템플릿 빌드 (Packer)

```bash
cd packer/vyos-template
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

`variables.pkrvars.hcl` 편집:

```hcl
proxmox_token = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"   # 토큰 시크릿(UUID)만
iso_checksum  = "none"    # 운영 환경에서는 "sha256:<hash>" 권장
```

빌드 실행:

```bash
packer init .
packer build -var-file=variables.pkrvars.hcl vyos-template.pkr.hcl
```

성공 시 PVE에 **VM ID 9000** 템플릿이 생성됩니다. (~10분)

---

## Step 4: Ubuntu 템플릿 빌드 (Packer)

```bash
cd packer/ubuntu-template
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

`variables.pkrvars.hcl` 편집:

```hcl
proxmox_token     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
iso_checksum      = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
ssh_password      = "ubuntu"
# 아래 명령으로 생성: openssl passwd -6 ubuntu
ssh_password_hash = "$6$..."
```

빌드 실행:

```bash
packer init .
packer build -var-file=variables.pkrvars.hcl ubuntu-template.pkr.hcl
```

성공 시 PVE에 **VM ID 9001** 템플릿이 생성됩니다. (~15분)

---

## Step 5: Terraform 초기화

```bash
cd ../../   # 루트 디렉토리로 이동
terraform init
terraform validate
```

---

## Step 6: VyOS 라우터 배포

```bash
terraform apply -target=module.vyos_rtr_1 -target=module.vyos_rtr_2
```

완료 후 확인:

```bash
# VRRP VIP 확인
terraform output vrrp_vip_vlan20   # 192.168.20.1

# VyOS SSH 접속 테스트
ssh vyos@$(terraform output -raw vyos_rtr_1_bootstrap_ip)
show interfaces
show vrrp
```

---

## Step 7: Mac → vlan20 라우팅 설정

개발 Mac은 192.168.219.x 대역이라 vlan20(192.168.20.x)에 직접 접근이 안 됩니다.
VyOS를 경유하는 정적 라우팅이 필요합니다.

```bash
VYOS_IP=$(terraform output -raw vyos_rtr_1_bootstrap_ip)

# 즉시 적용
sudo route -n add -net 192.168.20.0/24 ${VYOS_IP}

# 연결 확인
ping -c 2 192.168.20.1
```

**재부팅 후에도 유지하려면 (launchd):**

```bash
VYOS_IP=$(terraform output -raw vyos_rtr_1_bootstrap_ip)

sudo tee /Library/LaunchDaemons/com.homelab.routes.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.homelab.routes</string>
  <key>ProgramArguments</key>
  <array>
    <string>/sbin/route</string><string>add</string>
    <string>-net</string><string>192.168.20.0/24</string>
    <string>${VYOS_IP}</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF

sudo launchctl load /Library/LaunchDaemons/com.homelab.routes.plist
```

---

## Step 8: K8s 클러스터 배포

```bash
terraform apply
```

Ansible이 자동으로 실행되어 다음을 수행합니다:
1. 모든 노드 공통 설정 (containerd, sysctl)
2. k8s-cp1: kube-vip + kubeadm init
3. k8s-cp2/3: join as control plane
4. k8s-w1/2/3: join as worker
5. Cilium CNI + BGP policy 설치

완료까지 약 **15~20분** 소요됩니다.

---

## Step 9: 클러스터 검증

```bash
export KUBECONFIG=~/.kube/homelab-config

# 모든 노드 Ready 확인
kubectl get nodes -o wide

# 시스템 파드 상태 확인
kubectl get pods -n kube-system

# kube-vip VIP 확인 (192.168.20.10)
ping -c 2 192.168.20.10

# Cilium 상태
kubectl exec -n kube-system ds/cilium -- cilium status
```

**기대 출력:**

```
NAME      STATUS   ROLES           AGE   VERSION
k8s-cp1   Ready    control-plane   Xm    v1.32.x
k8s-cp2   Ready    control-plane   Xm    v1.32.x
k8s-cp3   Ready    control-plane   Xm    v1.32.x
k8s-w1    Ready    <none>          Xm    v1.32.x
k8s-w2    Ready    <none>          Xm    v1.32.x
k8s-w3    Ready    <none>          Xm    v1.32.x
```

---

## Step 10: VyOS BGP 활성화 (선택)

외부에서 Pod IP로 직접 접근이 필요한 경우 활성화합니다.
→ 상세: `docs/bgp-peering.md`

```hcl
# terraform.tfvars에 추가
vyos_bgp_enabled          = true
vyos_rtr_1_config_version = "v6"   # 기존 버전 + 1
vyos_rtr_2_config_version = "v4"
```

```bash
terraform apply

# Pod CIDR 라우팅 확인
ssh vyos@$(terraform output -raw vyos_rtr_1_bootstrap_ip) "show bgp summary"

# Mac에 Pod CIDR 라우팅 추가
sudo route -n add -net 10.244.0.0/16 ${VYOS_IP}
```

---

## 변수 레퍼런스

### 필수 변수 (반드시 설정)

| 변수명 | 설명 | 예시 |
|---|---|---|
| `pve_api_token` | Proxmox API 토큰 | `terraform@pve!provisioner=uuid` |
| `k8s_ssh_public_key` | K8s 노드 접근용 SSH 공개키 | `ssh-ed25519 AAAA...` |

### 선택 변수 (기본값이 있으나 환경에 맞게 수정)

| 변수명 | 기본값 | 설명 |
|---|---|---|
| `pve_endpoint` | `https://192.168.219.11:8006/` | PVE API 엔드포인트 |
| `pve_node_name` | `pve-node1` | VyOS/Ubuntu 템플릿 위치 노드 |
| `vyos_template_id` | `9000` | VyOS 템플릿 VM ID |
| `ubuntu_template_id` | `9001` | Ubuntu 템플릿 VM ID |
| `vyos_default_password` | `vyos` | VyOS 부트스트랩 비밀번호 |
| `k8s_vip` | `192.168.20.10` | K8s API server VIP |
| `k8s_pod_cidr` | `10.244.0.0/16` | Pod 네트워크 대역 |
| `k8s_service_cidr` | `10.96.0.0/12` | Service 네트워크 대역 |
| `k8s_ssh_private_key_path` | `~/.ssh/id_ed25519` | Ansible SSH 개인키 경로 |
| `k8s_kubeconfig_output_path` | `~/.kube/homelab-config` | kubeconfig 저장 경로 |
| `vyos_bgp_enabled` | `false` | VyOS BGP 활성화 |

### VRRP / IP 변수 (네트워크 대역이 다를 경우 수정)

| 변수명 | 기본값 | 설명 |
|---|---|---|
| `vrrp_vip_vlan10` | `192.168.10.1/24` | mgmt VLAN VIP |
| `vrrp_vip_vlan20` | `192.168.20.1/24` | k8s VLAN VIP (기본 게이트웨이) |
| `vrrp_vip_vlan30` | `192.168.30.1/24` | storage VLAN VIP |
| `vyos_rtr_1_vlan20_ip` | `192.168.20.252/24` | VyOS master vlan20 IP |
| `vyos_rtr_2_vlan20_ip` | `192.168.20.253/24` | VyOS backup vlan20 IP |

---

## 전체 흐름 요약

```
[수동]  PVE 설치 + 클러스터 구성
[수동]  NIC hang-fix 적용 (pve-node1/2/3)
[수동]  MikroTik VLAN 설정
[수동]  PVE API 토큰 생성

[Packer]  vyos-template  빌드 → VM 9000
[Packer]  ubuntu-template 빌드 → VM 9001

[terraform init]
[terraform apply]  vyos_rtr_1, vyos_rtr_2  → VyOS HA 라우터 배포
[수동]  Mac에 정적 라우팅 추가

[terraform apply]  k8s_cluster  → 6노드 K8s 클러스터 배포
                                  (Ansible 자동 실행)

[선택]  terraform.tfvars: vyos_bgp_enabled = true
[선택]  terraform apply  → VyOS BGP 활성화
```

---

## 자주 발생하는 문제

| 증상 | 확인 사항 |
|---|---|
| Packer 빌드 실패 | `build_ip`가 네트워크에서 충돌하지 않는지 확인 |
| K8s 노드 NotReady | `kubectl describe node <이름>` 으로 원인 확인 |
| kubectl 연결 불가 | Mac 정적 라우팅 확인: `netstat -rn | grep 192.168.20` |
| VyOS 프로비저닝 재실행 | `config_version` 값을 증가시킨 후 `terraform apply` |
| pve-node1 행업 | NIC hang-fix 적용 여부 확인 (docs/nic-hang-fix.md) |

---

## 참고 문서

- `docs/ARCHITECTURE.md` — 전체 아키텍처 학습 가이드
- `docs/kube-vip-bootstrap.md` — kube-vip HA 설계 상세
- `docs/bgp-peering.md` — VyOS ↔ Cilium BGP 피어링
- `docs/nic-hang-fix.md` — Intel NIC 행업 처치
