# VM Runbook: Vagrant + Kubernetes + CI/CD + Monitoring + ELK

This runbook explains how to start the full lab on local VMs and run the complete pipeline:

- Vagrant VM provisioning
- Local Gitea + runner + registry
- Kubernetes deployment on app1 (k3s)
- Monitoring stack (Prometheus, Grafana)
- ELK stack (Elasticsearch, Logstash, Kibana)

## 1. Prerequisites (Host Machine)

Install:

- Vagrant
- VirtualBox
- Git

Verify:

```powershell
vagrant --version
VBoxManage --version
git --version
```

## 2. Start the Full VM Environment

From repository root:

```powershell
vagrant up
```

If app1 existed before Kubernetes integration, reprovision app1:

```powershell
vagrant up app1 --provision
```

## 3. VM Roles and IPs

- lb1: 192.168.56.10
- web1: 192.168.56.11
- web2: 192.168.56.12
- app1: 192.168.56.13 (k3s cluster node)
- backup1: 192.168.56.14
- cicd1: 192.168.56.15 (Gitea, registry, runner)
- mon1: 192.168.56.16 (Prometheus, Grafana, ELK)

## 4. Verify Core Services

### 4.1 Load Balancer / App Access

```powershell
curl http://192.168.56.10/
curl http://192.168.56.10/api/health
curl http://192.168.56.10/api/metrics
```

### 4.2 CI/CD and Registry

Open in browser:

- Gitea: http://192.168.56.15:3000
- Registry API check: http://192.168.56.15:5000/v2/

### 4.3 Monitoring and ELK

Open in browser:

- Prometheus: http://192.168.56.16:9090
- Grafana: http://192.168.56.16:3000 (admin/admin)
- Kibana: http://192.168.56.16:5601
- Elasticsearch: http://192.168.56.16:9200

## 5. Kubernetes (k3s on app1)

Check cluster status:

```powershell
vagrant ssh app1 -c "sudo k3s kubectl get nodes"
vagrant ssh app1 -c "sudo k3s kubectl get pods -A"
```

Check app workloads:

```powershell
vagrant ssh app1 -c "sudo k3s kubectl get deploy,svc,hpa"
```

Quick app check via NodePort:

```powershell
vagrant ssh app1 -c "curl -I http://127.0.0.1:30007/"
```

## 6. CI/CD to Kubernetes Flow

On push to main:

1. Backend tests, lint, and security scan run.
2. Backend and frontend Docker images are built.
3. Images are pushed to local registry 192.168.56.15:5000.
4. Workflow connects to app1 over SSH.
5. k8s manifests are applied.
6. Deployment images are updated to the pushed commit SHA.
7. Rollout waits until success.

Trigger pipeline manually by committing to main:

```powershell
git add .
git commit -m "trigger pipeline"
git push origin main
```

## 7. Useful Operations

Re-run provisioning for one VM:

```powershell
vagrant provision app1
vagrant provision mon1
vagrant provision cicd1
```

SSH into a VM:

```powershell
vagrant ssh app1
vagrant ssh mon1
vagrant ssh cicd1
```

View k3s resources:

```bash
sudo k3s kubectl get all
sudo k3s kubectl describe deployment backend
sudo k3s kubectl logs deployment/backend
```

## 8. Troubleshooting

### 8.1 Kubernetes image pull issues

Check app1 can reach registry:

```bash
curl -s http://192.168.56.15:5000/v2/
```

If needed, reprovision app1:

```powershell
vagrant provision app1
```

### 8.2 Pipeline cannot SSH to app1

Re-run CI/CD provisioning on cicd1:

```powershell
vagrant provision cicd1
```

Confirm deploy key exists in repo secrets and app1 authorized keys were provisioned.

### 8.3 Monitoring dashboards empty

Check exporters on nodes and scrape targets in Prometheus:

```powershell
vagrant ssh mon1 -c "docker ps"
```

Open Prometheus targets page:

- http://192.168.56.16:9090/targets

### 8.4 ELK has no logs

Check Logstash and Filebeat services:

```powershell
vagrant ssh mon1 -c "docker logs logstash --tail 100"
vagrant ssh app1 -c "sudo systemctl status filebeat --no-pager"
```

## 9. Clean Rebuild

Destroy and rebuild all VMs:

```powershell
vagrant destroy -f
vagrant up
```

This is the fastest path to recover from inconsistent lab state.
