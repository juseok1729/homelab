# VyOS NAT 제외 대역 갱신 가이드 (mgmt_network 변경 반영)

> **작성일**: 2026-08-09
> **상태**: ⏳ 미적용 — 나중에 이 문서대로 진행

## 배경

2026-08-09 관리 네트워크 대역 이전(`192.168.219.0/24` → `172.30.1.0/24`, 커밋 `6fd5ec4`)으로
`modules/vyos-router/variables.tf`의 `mgmt_network` 기본값은 변경됐지만,
**실행 중인 VyOS 라우터 2대의 NAT 설정에는 아직 반영되지 않았다.**

라우터에는 여전히 옛 대역 기준의 NAT 제외 규칙이 남아 있다:

```
nat source rule 90  # no NAT: vlan10 → mgmt (destination 192.168.219.0/24)
nat source rule 91  # no NAT: vlan20 → mgmt (destination 192.168.219.0/24)
nat source rule 92  # no NAT: vlan30 → mgmt (destination 192.168.219.0/24)
```

이 규칙의 목적은 내부 VLAN에서 관리망으로 가는 트래픽을 masquerade에서 제외하는 것.
현재는 존재하지 않는 옛 대역을 제외하고 있으므로, **내부 VLAN → 172.30.1.x 트래픽이
불필요하게 NAT되는 상태**다 (동작에는 문제없지만 소스 IP가 가려짐).

## 왜 terraform apply만으로는 반영되지 않나

VyOS 설정은 `null_resource.provision`이 SSH로 적용하는데, 트리거가 `config_version`
변수뿐이다 (`modules/vyos-router/main.tf:60-63`). 즉 **`mgmt_network` 값만 바꿔서는
프로비저너가 재실행되지 않는다.** `config_version`을 올려야 전체 설정 스크립트가
재적용된다.

재적용 시 안심해도 되는 이유:

- 스크립트는 전부 `set` 명령이라 멱등(idempotent)이다. rule 90~92의
  `destination address`는 단일값 노드라서 옛 값이 새 값으로 **덮어써진다**
  (별도 삭제 작업 불필요).
- VM 자체는 재생성되지 않는다. `null_resource`만 교체되고, SSH로 설정만 다시 적용된다.
- 스크립트 끝에 `commit` + `save`가 포함돼 있어 재부팅 후에도 유지된다.

## 적용 절차

HA 구성이므로 **backup(rtr-2) 먼저 적용 → 검증 → master(rtr-1) 적용** 순서를 권장.

### 1. rtr-2 (backup) 적용

`terraform.tfvars`에서 버전을 올린다:

```hcl
vyos_rtr_2_config_version = "v5"   # v4 → v5
```

```bash
terraform apply
# plan에서 null_resource.provision 교체(replace) 1건만 나오는지 확인 후 승인
```

### 2. rtr-2 검증

```bash
ssh vyos@172.30.1.92 "show configuration commands | grep 'nat source rule 9'"
# → rule 90/91/92의 destination address가 172.30.1.0/24 인지 확인

ssh vyos@172.30.1.92 "show vrrp"
# → backup 상태 유지 확인
```

### 3. rtr-1 (master) 적용

```hcl
vyos_rtr_1_config_version = "v7"   # v6 → v7
```

```bash
terraform apply
```

### 4. 최종 검증

```bash
ssh vyos@172.30.1.64 "show configuration commands | grep 'nat source rule 9'"
ssh vyos@172.30.1.64 "show vrrp"          # master 상태 확인
kubectl get node                           # K8s BGP 경로 정상 확인

# NAT 제외가 실제로 동작하는지: K8s 노드에서 관리망으로 나갈 때
# 소스 IP가 VLAN IP 그대로 보이면 성공
ssh ubuntu@192.168.20.11 "ping -c 2 172.30.1.111"
```

## 주의사항

- **두 라우터를 동시에 올리지 말 것.** 한 대씩 적용해야 VRRP 페일오버로 무중단 유지.
- 프로비저너는 vlan1의 DHCP IP(`bootstrap_ip`)로 SSH 접속한다. 라우터 IP가 바뀌었다면
  `terraform plan`으로 상태를 먼저 refresh할 것 (현재: rtr-1 `172.30.1.64`, rtr-2 `172.30.1.92`).
- 적용 후 `terraform.tfvars`의 버전 값이 곧 "현재 라우터에 적용된 설정 버전"이 된다.
  tfvars는 gitignore 대상이므로, 버전을 올린 사실을 커밋 메시지나 이 문서에 기록해둘 것.

## 완료 후

- [ ] rtr-2 (v5) 적용 및 검증
- [ ] rtr-1 (v7) 적용 및 검증
- [ ] 이 문서 상단 상태를 ✅ 적용 완료로 변경
