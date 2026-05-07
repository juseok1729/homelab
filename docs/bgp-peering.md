# BGP 피어링: VyOS ↔ Cilium

## 개요

VyOS(AS 65000)와 K8s 클러스터의 Cilium(AS 65001)이 eBGP로 피어링합니다.
각 노드가 자신의 Pod CIDR을 VyOS에 광고하면 VyOS는 이를 라우팅 테이블에 추가합니다.
결과적으로 홈랩 내부 어디서든 Pod IP로 직접 접근이 가능해집니다.

---

## 구성 요소

### VyOS 측 (AS 65000)

```
# terraform.tfvars
vyos_bgp_enabled = true

# modules/vyos-router/locals.tf 에서 자동 생성
set protocols bgp system-as '65000'
set protocols bgp neighbor 192.168.20.11 remote-as '65001'
set protocols bgp neighbor 192.168.20.11 address-family ipv4-unicast
...  (6개 노드 전부)
```

- BGP 라우터 ID: VyOS eth0 IP (예: 192.168.219.106)
- 피어: k8s 노드 6개 (CP 3 + Worker 3)
- 수신: 각 노드의 Pod CIDR (/24)

### Cilium 측 (AS 65001)

```yaml
# ansible/k8s-bootstrap/roles/cilium/templates/cilium-bgp-policy.yaml.j2
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeeringPolicy
metadata:
  name: homelab-bgp-peering
spec:
  nodeSelector:
    matchLabels: {}       # 모든 노드에 적용
  virtualRouters:
  - localASN: 65001
    exportPodCIDR: true   # 노드별 Pod CIDR을 BGP로 광고
    neighbors:
    - peerAddress: "192.168.20.1/32"   # VyOS VRRP VIP
      peerASN: 65000
      holdTimeSeconds: 9
      keepAliveTimeSeconds: 3
```

Cilium Helm 설치 옵션:
```
--set bgpControlPlane.enabled=true
--set routingMode=native              # eBPF native routing
--set autoDirectNodeRoutes=true       # 노드 간 직접 라우팅
--set ipv4NativeRoutingCIDR=10.244.0.0/16
```

---

## 활성화 방법

BGP는 기본값 비활성화이며 K8s 클러스터 배포 후 별도로 활성화합니다.

```hcl
# terraform.tfvars
vyos_bgp_enabled          = true
vyos_rtr_1_config_version = "v6"   # 기존 버전 + 1 (재프로비저닝 트리거)
vyos_rtr_2_config_version = "v4"
```

```bash
terraform apply
```

---

## 정상 동작 확인

### VyOS에서 피어링 상태 확인

```bash
ssh vyos@192.168.219.106
show bgp summary
```

**정상 출력:**
```
Neighbor        V    AS   MsgRcvd  MsgSent  Up/Down  State/PfxRcd
192.168.20.11   4  65001      33       39  00:01:32            1
192.168.20.12   4  65001      23       29  00:01:01            1
192.168.20.13   4  65001      34       40  00:01:34            1
192.168.20.21   4  65001      13       19  00:00:30            1
192.168.20.22   4  65001      17       23  00:00:43            1
192.168.20.23   4  65001      14       20  00:00:33            1
```

- `State/PfxRcd = 1`: 각 노드로부터 Pod CIDR 1개 수신 ✓
- `PfxSnt = 6`: VyOS가 모든 Pod CIDR을 되돌려 광고 ✓

### VyOS 라우팅 테이블 확인

```bash
show ip route bgp
```

**정상 출력:**
```
B>* 10.244.0.0/24 via 192.168.20.11, eth0.20   ← k8s-cp1 Pod 대역
B>* 10.244.1.0/24 via 192.168.20.12, eth0.20   ← k8s-cp2 Pod 대역
B>* 10.244.2.0/24 via 192.168.20.13, eth0.20   ← k8s-cp3 Pod 대역
B>* 10.244.3.0/24 via 192.168.20.21, eth0.20   ← k8s-w1 Pod 대역
B>* 10.244.4.0/24 via 192.168.20.23, eth0.20   ← k8s-w3 Pod 대역
B>* 10.244.5.0/24 via 192.168.20.22, eth0.20   ← k8s-w2 Pod 대역
```

### Cilium 피어링 상태 확인

```bash
kubectl get CiliumBGPPeeringPolicy
kubectl exec -n kube-system ds/cilium -- cilium bgp peers
```

---

## Pod CIDR 할당 방식

Cilium은 IPAM 모드 `kubernetes`를 사용합니다.
kubeadm이 `podSubnet: 10.244.0.0/16`을 설정하면
각 노드에 `/24` 블록이 자동 할당됩니다.

```
10.244.0.0/16  (전체 Pod 대역)
  ├─ 10.244.0.0/24  → k8s-cp1
  ├─ 10.244.1.0/24  → k8s-cp2
  ├─ 10.244.2.0/24  → k8s-cp3
  ├─ 10.244.3.0/24  → k8s-w1
  ├─ 10.244.4.0/24  → k8s-w3
  └─ 10.244.5.0/24  → k8s-w2
```

---

## BGP의 효과

### BGP 없을 때

```
Mac → Pod IP(10.244.x.x) 접근 불가
     (VyOS가 10.244.x.x 라우트를 모름)
```

### BGP 있을 때

```
Mac
 └─ route: 192.168.20.0/24 via 192.168.219.106 (VyOS)
     └─ VyOS BGP 라우트: 10.244.0.0/24 via 192.168.20.11
         └─ k8s-cp1 (Cilium eBPF) → Pod 직접 전달
```

Mac에서 정적 라우트 추가 필요:
```bash
sudo route -n add -net 10.244.0.0/16 192.168.219.106
```

---

## 주요 파라미터

| 파라미터 | 값 | 설명 |
|---|---|---|
| VyOS AS | 65000 | `bgp_local_as` |
| Cilium AS | 65001 | `k8s_bgp_as` |
| BGP peer (VyOS → K8s) | 192.168.20.11~23 | k8s 노드 IP |
| BGP peer (K8s → VyOS) | 192.168.20.1 | VyOS VRRP VIP |
| Pod CIDR | 10.244.0.0/16 | `k8s_pod_cidr` |
| Hold Time | 9s | keepalive × 3 |
| Keepalive | 3s | 기본값 |
