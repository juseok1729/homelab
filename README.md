# Homelab
<!-- toc -->

- [Installation](#installation)
  - [Phase1](#phase1)

<!-- tocstop -->


## Installation
### Phase1
0. 위 파일 clone 후  
1. terraform.tfvars 만들고 실제 토큰 secret 주입  
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    # 편집: pve_api_token에 실제 값
    ```

2. .ssh-agent에 PVE root SSH key 등록 (provider가 SSH 사용)  
    ```bash
    ssh-add ~/.ssh/id_rsa  # PVE root SSH 가능한 key

    # 미리 한 번 SSH 접속해서 host key trust 받아두기
    ssh root@192.168.219.11 'echo PVE-SSH-OK'
    ssh root@192.168.219.12 'echo PVE-SSH-OK'
    ssh root@192.168.219.13 'echo PVE-SSH-OK'
    ```


3. Terraform 초기화
    ```bash
    terraform init
    ```

4. fmt + validate
    ```bash
    terraform fmt
    terraform validate
    ```

5. Plan
    ```bash
    terraform plan -out=phase1.tfplan
    # 출력 검토:
    #   + proxmox_virtual_environment_vm.vyos_rtr_1
    #   1 to add, 0 to change, 0 to destroy
    ```

6. Apply
    ```bash
    terraform apply phase1.tfplan
    ```

### Phase2
```bash
SSH 접속 (vyos@192.168.219.106)
   ↓
remote-exec가 명령을 SSH로 전달:
   bash -c "vbash <<'VYOS_EOF'
              source /opt/vyatta/etc/functions/script-template
              configure
              set ...
              commit
              save
              exit
              VYOS_EOF"
   ↓
SSH 세션의 default shell(bash)에서 실행
   ↓
bash가 vbash를 실행 + heredoc 내용을 stdin으로 전달
   ↓
vbash가 script-template 로드 (하이픈 함수명 OK)
   ↓
configure → set → commit → save 실행
```

1. 실행
```vbash
terraform fmt
terraform validate
terraform plan -out=phase2.tfplan
terraform apply phase2.tfplan
```

2. 검증
```vbash
# 1. Hostname 확인
vyos@<Hostname>:~$    # 프롬프트에서 vyos-rtr-1로 변경됐는지 확인

# 2. VLAN sub-interfaces
vyos@vyos-rtr-1:~$ show interfaces
# 기대 출력:
#   eth0       192.168.219.106/24   ...   default   1500   u/u
#   eth0.10    192.168.10.252/24    ...   default   1500   u/u
#   eth0.20    192.168.20.252/24    ...   default   1500   u/u
#   eth0.30    192.168.30.252/24    ...   default   1500   u/u
#   lo         127.0.0.1/8          ...

# 3. NAT rules
vyos@vyos-rtr-1:~$ show nat source rules
# 100, 110, 120 rules 보여야 함

# 4. Firewall global state policy
vyos@vyos-rtr-1:~$ show configuration | grep -A 30 "firewall {"
# firewall {
#     global-options {
#         state-policy {
#             established {
#                 action accept
#             }
#             invalid {
#                 action drop
#             }
#             related {
#                 action accept
#             }
#         }
#     }
# }
# interfaces {
#     ethernet eth0 {
#         address dhcp
#         hw-id bc:24:11:ef:57:73
#         vif 10 {
#             address 192.168.10.252/24
#             description mgmt
#         }
#         vif 20 {
#             address 192.168.20.252/24
#             description k8s-svc
#         }
#         vif 30 {
#             address 192.168.30.252/24
#             description storage
#         }

# 5. Routing
vyos@vyos-rtr-1:~$ show ip route
# 기대:
#   S>* 0.0.0.0/0 via 192.168.219.1
#   C>* 192.168.10.0/24 directly connected eth0.10
#   C>* 192.168.20.0/24 directly connected eth0.20
#   C>* 192.168.30.0/24 directly connected eth0.30
#   C>* 192.168.219.0/24 directly connected eth0

# 6. (보너스) Config 전체
vyos@vyos-rtr-1:~$ show configuration commands | grep -E "host-name|vif|nat|firewall"
```

3. 체크
```
✅ Hostname: vyos-rtr-1
✅ vlan10/20/30 sub-interfaces (.252 IPs, descriptions)
✅ NAT rules 100/110/120 (vlan10/20/30 → eth0 masquerade)
✅ Firewall state-policy (set 명령 정상 박힘)
✅ Routing: connected vlan10/20/30 + static default
✅ External SSH 여전히 가능 (vlan1 DHCP IP 유지 — 디버깅 fallback)
```
