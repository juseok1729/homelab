# Phase1
0. 위 파일 모두 생성 후  
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
terraform plan -out=phase2.tfplan
# 출력 검토:
#   + proxmox_virtual_environment_vm.vyos_rtr_1
#   1 to add, 0 to change, 0 to destroy
```

6. Apply
```bash
terraform apply phase2.tfplan
```
