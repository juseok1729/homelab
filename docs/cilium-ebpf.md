# Cilium eBPF CNI

## 개요

이 클러스터는 Cilium을 **eBPF 네이티브 모드**로 구성합니다.
kube-proxy를 완전히 제거하고 eBPF 프로그램이 커널 레벨에서
패킷 처리, 로드밸런싱, 마스커레이딩을 직접 수행합니다.

---

## 구성 옵션

### Helm 설치 플래그

```bash
# ansible/k8s-bootstrap/roles/cilium/tasks/main.yml
helm upgrade --install cilium cilium/cilium \
  --version {{ cilium_version }} \
  --namespace kube-system \
  --set kubeProxyReplacement=true \       # kube-proxy 완전 대체
  --set k8sServiceHost={{ k8s_vip }} \    # API server 주소 (VIP)
  --set k8sServicePort=6443 \
  --set bgpControlPlane.enabled=true \    # BGP Control Plane 활성화
  --set ipam.mode=kubernetes \            # K8s 노드별 CIDR 할당
  --set ipv4NativeRoutingCIDR=10.244.0.0/16 \
  --set bpf.masquerade=true \             # eBPF masquerade (iptables 제거)
  --set routingMode=native \              # eBPF native routing (터널링 없음)
  --set autoDirectNodeRoutes=true         # 노드 간 직접 라우팅
```

### 각 옵션 설명

| 옵션 | 값 | 의미 |
|---|---|---|
| `kubeProxyReplacement` | `true` | kube-proxy 없이 eBPF가 Service 처리 |
| `routingMode` | `native` | VXLAN/Geneve 터널링 없이 직접 라우팅 |
| `bpf.masquerade` | `true` | iptables 대신 eBPF로 SNAT 처리 |
| `autoDirectNodeRoutes` | `true` | 같은 L2 노드 간 Pod 직접 통신 |
| `ipam.mode` | `kubernetes` | kubeadm이 할당한 podCIDR 사용 |
| `bgpControlPlane.enabled` | `true` | VyOS와 BGP 피어링 활성화 |

---

## 현재 동작 상태 확인

```bash
kubectl exec -n kube-system ds/cilium -- cilium status | grep -E "KubeProxy|BPF|Routing"
```

**출력 해석:**

```
KubeProxyReplacement: True [eth0 192.168.20.11 192.168.20.10 ...]
  ↑ kube-proxy 완전 대체됨. eth0 인터페이스에서 동작

Routing: Network: Native   Host: BPF
  ↑ 파드 간 라우팅: eBPF native (터널링 없음)
  ↑ 호스트 네트워크 정책: BPF 처리

Masquerading: BPF [eth0]  10.244.0.0/16 [IPv4: Enabled]
  ↑ Pod → 외부 SNAT을 iptables 없이 eBPF가 처리
```

kube-proxy가 없음을 확인:

```bash
# 결과가 비어있어야 정상
kubectl exec -n kube-system ds/cilium -- cilium status --verbose | grep "kube-proxy"

# kube-proxy 파드가 없어야 정상
kubectl get pods -n kube-system | grep kube-proxy
```

---

## 일반 CNI(flannel 등)와의 차이

```
일반 CNI + kube-proxy:
  파드 → iptables → SNAT → 네트워크
         (규칙 수천 개, 매 패킷마다 순차 탐색)

Cilium eBPF native:
  파드 → eBPF 맵 → 직접 포워딩
         (해시 테이블 O(1) 조회, 커널 내 처리)
```

**성능 이점:**
- 서비스 수가 늘어도 iptables처럼 선형적으로 느려지지 않음
- 커널 컨텍스트 스위치 감소
- 네트워크 정책 적용 오버헤드 최소화

---

## 패킷 흐름

### Pod → Service (ClusterIP)

```
Pod(10.244.x.x)
  → eBPF socket hook (소켓 레벨에서 Service IP를 Pod IP로 변환)
  → 목적지 Pod로 직접 전달 (네트워크 스택 우회)
```

### Pod → 외부 인터넷

```
Pod(10.244.x.x)
  → eBPF masquerade (SNAT: 10.244.x.x → 192.168.20.x)
  → VyOS → 인터넷
```

### 외부 → Pod (BGP 활성화 시)

```
Mac(192.168.219.x)
  → VyOS (BGP 라우트: 10.244.0.0/24 via 192.168.20.11)
  → k8s-cp1 (Cilium eBPF → 해당 Pod 직접 전달)
```

---

## 유용한 진단 명령어

```bash
# Cilium 전체 상태
kubectl exec -n kube-system ds/cilium -- cilium status

# 엔드포인트 목록 (파드별 eBPF 프로그램)
kubectl exec -n kube-system ds/cilium -- cilium endpoint list

# 서비스 목록 (kube-proxy 대신 eBPF가 관리)
kubectl exec -n kube-system ds/cilium -- cilium service list

# BGP 피어 상태
kubectl exec -n kube-system ds/cilium -- cilium bgp peers

# 특정 파드의 네트워크 정책
kubectl exec -n kube-system ds/cilium -- cilium policy get
```

---

## 트러블슈팅

### Pod 간 통신 안 될 때

```bash
# 연결 테스트
kubectl exec -n kube-system ds/cilium -- cilium connectivity test

# 특정 엔드포인트 상태
kubectl exec -n kube-system ds/cilium -- cilium endpoint get <id>
```

### eBPF 맵 확인

```bash
# Service 맵 (ClusterIP → Endpoint 매핑)
kubectl exec -n kube-system ds/cilium -- cilium bpf lb list

# NAT 맵
kubectl exec -n kube-system ds/cilium -- cilium bpf nat list
```

---

## Hubble — 네트워크 가시성

Hubble은 Cilium 위에서 동작하는 네트워크 플로우 관찰 도구입니다.
eBPF로 수집한 패킷 흐름을 시각화하고, 서비스 간 통신 현황을 실시간으로 확인할 수 있습니다.

### 구성 요소

| 컴포넌트 | 역할 |
|---|---|
| Hubble Agent | 각 노드의 Cilium에 내장 — 로컬 플로우 수집 |
| Hubble Relay | 전체 노드 플로우 집계 (gRPC 허브) |
| Hubble UI | 웹 대시보드 — 서비스맵, 플로우 시각화 |

### 설치 (Helm)

초기 Cilium 설치 후 별도로 활성화합니다.

```bash
helm upgrade cilium cilium/cilium \
  --version 1.17.0 \
  --namespace kube-system \
  --reuse-values \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}"
```

**활성화된 메트릭:**

| 메트릭 | 수집 내용 |
|---|---|
| `dns` | DNS 쿼리/응답 |
| `drop` | 드롭된 패킷 + 이유 |
| `tcp` | TCP 연결 상태 |
| `flow` | 전체 네트워크 플로우 |
| `port-distribution` | 포트별 트래픽 분포 |
| `icmp` | ICMP 패킷 |
| `http` | HTTP 요청/응답 (상태코드 등) |

### 파드 확인

```bash
kubectl get pods -n kube-system | grep hubble
# hubble-relay-xxx   1/1 Running
# hubble-ui-xxx      2/2 Running
```

### UI 접근 (포트포워딩)

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

브라우저에서 `http://localhost:12000` 접속.

### CLI로 플로우 확인

```bash
# hubble CLI 설치 (macOS)
brew install hubble

# Relay에 연결
hubble config set server localhost:4245
kubectl port-forward -n kube-system svc/hubble-relay 4245:80 &

# 실시간 플로우 모니터링
hubble observe --follow

# 특정 네임스페이스만
hubble observe --namespace default --follow

# 드롭된 패킷만
hubble observe --verdict DROPPED --follow
```

### Hubble 상태 확인

```bash
kubectl exec -n kube-system ds/cilium -- cilium status | grep -i hubble
# Hubble: Ok   Current/Max Flows: 4095/4095   Metrics: Enabled
```
