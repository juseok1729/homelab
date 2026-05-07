[control_plane]
%{ for cp in control_planes ~}
${cp.name} ansible_host=${cp.ip} ansible_user=ansible
%{ endfor ~}

[workers]
%{ for w in workers ~}
${w.name} ansible_host=${w.ip} ansible_user=ansible
%{ endfor ~}

[k8s_cluster:children]
control_plane
workers
