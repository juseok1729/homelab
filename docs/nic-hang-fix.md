# Intel I219-LM NIC Hang 이슈 및 처치

## 현상

pve-node1 (Lenovo ThinkCentre M70q Gen 6)이 k8s 클러스터 부트스트랩 도중
반복적으로 네트워크가 끊기며 노드가 죽는 현상 발생.

커널 로그에서 다음 메시지 반복 출력 후 SSH 세션 종료:

```
kernel: e1000e 0000:80:1f.6 nic0: Detected Hardware Unit Hang:
    TDH <8e>  TDT <b0>  next_to_use <b0>  next_to_clean <8d>
    ...
    MAC Status <80083>
```

## 원인

### NIC 모델

| 노드 | 머신 | NIC 칩셋 | 드라이버 |
|---|---|---|---|
| pve-node1 | Lenovo M70q Gen 6 | Intel I219-LM | e1000e |
| pve-node2 | Dell OptiPlex 7070 Micro | Intel I219-LM | e1000e |
| pve-node3 | Dell OptiPlex 7070 Micro | Intel I219-LM | e1000e |

세 노드 모두 동일 칩셋 패밀리이므로 동일 현상이 발생할 수 있다.

### 트리거 조건

e1000e 드라이버의 TX 큐 고착(Hardware Unit Hang)은 다음 조건에서 발생 빈도가 높다:

1. **가상화 환경에서의 높은 패킷 레이트**: Proxmox vmbr0 브릿지를 통해 여러 VM의
   트래픽이 동시에 흐를 때
2. **컨테이너 이미지 대량 pull**: k8s 부트스트랩 시 kubeadm, Cilium, etcd 이미지를
   동시에 받는 과정에서 네트워크 I/O 폭발
3. **TX/RX 오프로딩과 가상화 레이어 간 충돌**: NIC 하드웨어 오프로딩이 Proxmox
   브릿지 처리와 충돌

pve-node1이 가장 먼저 발생한 이유는 vyos-rtr-1 + k8s-cp1 + k8s-w1(4c/8GB)으로
트래픽이 가장 집중됐기 때문.

## 해결책: NIC 오프로딩 비활성화

### 오프로딩 기능 설명

| 기능 | 역할 | 끄는 이유 |
|---|---|---|
| TSO (TCP Segmentation Offload) | 대형 TCP 패킷 분할을 NIC가 처리 | 가상화 브릿지와 충돌 |
| GRO (Generic Receive Offload) | 수신 패킷 합산 후 CPU 전달 | TX hang 유발 |
| GSO (Generic Segmentation Offload) | TSO의 소프트웨어 버전 | 동일 |
| RX/TX Checksumming | 패킷 체크섬 계산 오프로드 | 안전을 위해 함께 비활성화 |

오프로딩을 끄면 CPU가 소프트웨어로 처리하므로 NIC 하드웨어 버그를 우회한다.
CPU 부하 증가는 홈랩 수준 트래픽에서 체감 없음 (1~2% 미만).

### 적용 방법 (모든 PVE 노드 공통)

```bash
# 즉시 적용
ethtool -K nic0 tso off gso off gro off rx off tx off
ethtool -K vmbr0 tso off gso off gro off rx off tx off

# 재부팅 후에도 유지되도록 systemd 서비스 등록
cat << 'EOF' > /etc/systemd/system/nic-hang-fix.service
[Unit]
Description=Disable e1000e offloading to prevent NIC hang
After=network-online.target
Wants=network-online.target

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

### 적용 확인

```bash
ethtool -k nic0 | grep -E "tcp-segmentation|generic-segmentation|generic-receive|rx-checksumming|tx-checksumming"
# 모두 off 이어야 함

systemctl is-enabled nic-hang-fix.service
# enabled 이어야 함
```

## 적용 현황

| 노드 | 적용일 | 방법 | 상태 |
|---|---|---|---|
| pve-node1 | 2026-05-07 | systemd 서비스 | ✅ 완료 |
| pve-node2 | - | 미적용 | ⚠️ 적용 권장 |
| pve-node3 | - | 미적용 | ⚠️ 적용 권장 |

## 참고

- k8s 부트스트랩(destroy → apply) 전에 모든 노드에 적용 권장
- 커널 업그레이드 시 재확인 필요 (`dkms` 모듈 재빌드 후 동작 변경 가능)
- 근본적인 해결책은 Intel 드라이버 패치이나 홈랩 환경에서는 오프로딩 비활성화로 충분
