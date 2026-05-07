# kube-vip HA 설계 및 Bootstrap 문제 해결

## 개요

kube-vip은 쿠버네티스 컨트롤 플레인의 Virtual IP(VIP)를 제공하는 도구입니다.
API server를 `192.168.20.10:6443`(VIP)으로 고정시켜 CP 노드가 하나 다운되어도
클러스터에 계속 접근할 수 있게 합니다.

---

## 최종 설계

### 핵심 아이디어: kube-vip.conf

kube-vip은 쿠버네티스 API에 접근해 리더 선출(lease)을 수행합니다.
일반 kubeconfig(admin.conf)는 서버 주소로 VIP(`192.168.20.10:6443`)를 사용하는데,
재부팅 시 VIP가 아직 없으면 kube-vip이 API에 연결하지 못해 크래시합니다.

**해결책**: 각 CP 노드 전용 kubeconfig(`kube-vip.conf`)를 만들어
서버 주소를 **노드 자신의 IP**로 설정합니다.

```yaml
# /etc/kubernetes/kube-vip.conf
clusters:
- cluster:
    certificate-authority-data: <CA>
    server: https://192.168.20.11:6443   # k8s-cp1의 경우
  name: homelab
```

- TLS 인증서가 노드 IP를 SAN으로 포함하므로 TLS 검증 통과
- VIP 없이도 로컬 API 서버에 직접 연결 가능
- CP마다 자신의 노드 IP를 사용 (CP2→.12, CP3→.13)

### kube-vip Manifest 설계

```yaml
# /etc/kubernetes/manifests/kube-vip.yaml 핵심 부분
volumeMounts:
- mountPath: /.kube/config   # kube-vip이 fallback으로 사용하는 경로
  name: kubeconfig
volumes:
- hostPath:
    path: /etc/kubernetes/kube-vip.conf
    type: FileOrCreate        # 없으면 빈 파일 생성 (bootstrap 시 정상)
  name: kubeconfig
```

**왜 `/.kube/config`인가?**
kube-vip 컨테이너의 HOME이 `/`이므로 `$HOME/.kube/config` = `/.kube/config`.
KUBECONFIG 환경변수나 `--k8sConfigPath` 플래그는 이 버전에서 무시됨.

---

## Bootstrap 타이밍 문제 해결

### 문제: 닭-달걀 순환

```
kubeadm init → API health check → https://192.168.20.10:6443 필요
kube-vip     → VIP 선점하려면 → k8s API 연결 필요 (리더 선출)
```

### 해결: ip addr add로 임시 VIP 주입

```yaml
# ansible/k8s-bootstrap/roles/kubeadm-init/tasks/main.yml
- name: Add API server VIP to interface (bootstrap)
  command: ip addr add {{ k8s_vip }}/32 dev {{ ansible_default_ipv4.interface }}
  failed_when: false
```

kubeadm init 전에 VIP를 직접 인터페이스에 추가하면:
1. kubeadm API health check가 `192.168.20.10:6443`으로 통과
2. kubeadm init 완료 → admin.conf 생성
3. kube-vip.conf 생성 (노드 IP 서버)
4. kube-vip pod 재시작 → kube-vip.conf 읽음 → k8s API 연결
5. k8s lease 획득 → VIP 정식 관리 시작 (ip addr add 상태 유지 또는 교체)

---

## Bootstrap 단계별 흐름

```
┌─────────────────────────────────────────────────────┐
│ 1. kube-vip manifest 배치                           │
│    /etc/kubernetes/manifests/kube-vip.yaml          │
│    → kube-vip.conf 없음 → /.kube/config 빈 파일    │
│    → kube-vip 크래시 (CrashLoopBackOff) → 정상     │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ 2. ip addr add 192.168.20.10/32 dev eth0            │
│    VIP 임시 활성화 (bootstrap 전용)                 │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ 3. kubeadm init                                     │
│    → [api-check] https://192.168.20.10:6443 → ✓    │
│    → admin.conf 생성                                │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ 4. kube-vip.conf 생성                               │
│    admin.conf 복사 후 server를 노드IP로 교체        │
│    server: https://192.168.20.11:6443               │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ 5. kube-vip pod 재시작                              │
│    → /.kube/config = kube-vip.conf 읽음            │
│    → 192.168.20.11:6443 연결 (TLS 통과)             │
│    → k8s lease 획득 → VIP 정식 관리                │
└─────────────────────────────────────────────────────┘
```

---

## 재부팅 후 동작

```
VM 재부팅
  → kubelet 시작
  → kube-vip static pod 기동
  → /.kube/config = kube-vip.conf 읽음
  → server: https://192.168.20.<N>:6443 (로컬 노드 IP)
  → kube-apiserver도 동시에 기동 중 (retry로 대기)
  → k8s lease 획득 → VIP 선점
  → kubectl 접근 가능
```

이전 리더 노드가 재부팅되면 다른 노드의 kube-vip이 lease를 갱신하여
VIP를 이어받습니다.

---

## 주요 트러블슈팅 기록

| 증상 | 원인 | 해결 |
|---|---|---|
| `unknown flag: --kubeconfig` | kube-vip flag 이름 변경 (`--k8sConfigPath`) | `/.kube/config` 마운트로 우회 |
| `/.kube/config` 사용 | KUBECONFIG 환경변수 무시됨 | 경로에 직접 마운트 |
| `tls: not 127.0.0.1` | API 서버 TLS cert에 127.0.0.1 미포함 | 노드 IP 사용 |
| VIP 없이 API 연결 불가 | 재부팅 후 VIP 선점 전 연결 시도 | kube-vip.conf에 노드 IP 설정 |
| kubeadm API health check 실패 | kube-vip 기동 전 VIP 없음 | `ip addr add`로 임시 VIP |
| YAML 들여쓰기 깨짐 | sed로 YAML 수정 시 공백 추가됨 | Python yaml 파싱으로 교체 |
