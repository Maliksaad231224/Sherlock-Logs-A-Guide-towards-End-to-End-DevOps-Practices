# VM Runbook: Vagrant, Docker, Kubernetes, ELK, Monitoring, and Backup

This runbook documents the local VM lab exactly as it is assembled by the repository scripts. The goal is to provision a reproducible environment that demonstrates:

- Vagrant-based virtual machine provisioning
- Docker image builds and local registry usage
- Kubernetes deployment with k3s
- CI/CD services based on Gitea and act_runner
- Monitoring with Prometheus and Grafana
- Logging with Elasticsearch, Logstash, and Kibana
- Backup and restore using rsync

## 1. Project Purpose

Sherlock Logs is a local virtualized lab for learning and demonstrating a complete infrastructure stack. It uses Vagrant to create the VMs, Docker to package the frontend and backend, Kubernetes to run the application, ELK for log visibility, and monitoring tools to observe the environment end to end.

## 2. Host Prerequisites

Install these on the host machine before starting:

- Vagrant
- VirtualBox
- Git
- Docker Engine

Verify the host tools:

```powershell
vagrant --version
VBoxManage --version
git --version
docker --version
```

## 3. VM Topology

The Vagrant environment creates a small networked lab with static IPs on `192.168.56.0/24`:

- `lb1` - `192.168.56.10` - load balancer and WireGuard VPN
- `web1` - `192.168.56.11` - web tier
- `web2` - `192.168.56.12` - web tier
- `app1` - `192.168.56.13` - application server and k3s node
- `backup1` - `192.168.56.14` - rsync backup node
- `cicd1` - `192.168.56.15` - Docker registry, Gitea, and act_runner
- `mon1` - `192.168.56.16` - Prometheus, Grafana, and ELK services

## 4. Provisioning Flow

The lab is split into role-based provisioning scripts under [provision](../provision):

- `base.sh` configures the shared security baseline on every VM
- `lb.sh` installs Nginx, configures the load balancer, and sets up WireGuard
- `web.sh` configures the web VMs and routes `/app/` to the app server
- `app.sh` installs the simple application service on `app1`
- `k8s.sh` installs k3s and prepares the Kubernetes client configuration on `app1`
- `docker.sh` installs Docker Engine and enables logins
- `cicd.sh` provisions the local registry, Gitea, and act_runner on `cicd1`
- `monitoring.sh` installs Prometheus, Grafana, and ELK components on `mon1`
- `backup.sh` configures rsync-based backups on `backup1`

## 5. Bring Up the Lab

From the repository root:

```powershell
vagrant up
```

If you need to reprovision after changing scripts:

```powershell
vagrant provision lb1
vagrant provision web1
vagrant provision web2
vagrant provision app1
vagrant provision backup1
vagrant provision cicd1
vagrant provision mon1
```

## 6. Docker Setup

The `provision/docker.sh` script installs Docker Engine from Docker’s official repository and starts the Docker service. It is the base requirement for building and running the frontend and backend images on the CI/CD VM.

Once Docker is installed, the CI/CD VM hosts a local registry at:

- `http://192.168.56.15:5000`

## 7. Kubernetes Setup

The Kubernetes layer is installed by `provision/k8s.sh` on `app1`.

What it does:

- Installs k3s if it is not already present
- Configures `/home/devops/.kube/config`
- Points the kubeconfig at `192.168.56.13`
- Allows access to the Kubernetes API and frontend NodePort from the lab subnet
- Configures container registry access for `192.168.56.15:5000`

Useful checks on `app1`:

```powershell
vagrant ssh app1 -c "sudo k3s kubectl get nodes"
vagrant ssh app1 -c "sudo k3s kubectl get pods -A"
vagrant ssh app1 -c "sudo k3s kubectl get svc"
```

## 8. CI/CD Setup

The `provision/cicd.sh` script creates the local delivery stack on `cicd1`:

- Local Docker registry on port `5000`
- Gitea on port `3000`
- Gitea SSH on port `2222`
- act_runner connected to the local Gitea instance
- Exported deploy artifacts in `/vagrant`

Generated files used by the rest of the lab:

- `act_runner.url`
- `act_runner.token`
- `cicd_deploy.pub`

Open the services in a browser:

- Gitea: `http://192.168.56.15:3000`
- Registry: `http://192.168.56.15:5000/v2/`

## 9. Monitoring and Logging

The `provision/monitoring.sh` script installs the observability stack on `mon1`.

It creates configuration for:

- Prometheus
- Grafana
- Alertmanager
- Logstash
- Elasticsearch dashboards and rules

The script also opens the required firewall ports for:

- Prometheus on `9090`
- Grafana on `3000`
- Kibana on `5601`
- Elasticsearch on `9200`
- Logstash Beats input on `5044`

Common URLs:

- Prometheus: `http://192.168.56.16:9090`
- Grafana: `http://192.168.56.16:3000`
- Kibana: `http://192.168.56.16:5601`
- Elasticsearch: `http://192.168.56.16:9200`

## 10. Backup and Restore

The `provision/backup.sh` script configures `backup1` as an rsync-based backup node.

What it does:

- Generates a dedicated backup SSH keypair
- Exports the public key to `/vagrant/backup_devops_authorized_keys`
- Installs a weekly backup timer
- Creates restore tooling for selected hosts and paths

The backup job pulls data from:

- `lb1`
- `web1`
- `web2`
- `app1`

## 11. Application Build and Deploy

The application images are built and deployed with the commands in [scripts/local-deploy.sh](../scripts/local-deploy.sh).

Typical flow:

```bash
cd frontend
docker build -t 192.168.56.15:5000/sherlock-logs-frontend:prod .
docker tag 192.168.56.15:5000/sherlock-logs-frontend:prod 192.168.56.15:5000/sherlock-logs-frontend:latest

cd ../backend
docker build -t 192.168.56.15:5000/sherlock-logs-backend:prod .
docker tag 192.168.56.15:5000/sherlock-logs-backend:prod 192.168.56.15:5000/sherlock-logs-backend:latest

cd ..
docker push 192.168.56.15:5000/sherlock-logs-frontend:prod
docker push 192.168.56.15:5000/sherlock-logs-frontend:latest
docker push 192.168.56.15:5000/sherlock-logs-backend:prod
docker push 192.168.56.15:5000/sherlock-logs-backend:latest

kubectl apply -f manifests/kubernates/
kubectl rollout restart deployment/sherlock-logs-frontend
kubectl rollout restart deployment/sherlock-logs-backend
```

## 12. Kubernetes Manifests

The manifests under [manifests/kubernates](../manifests/kubernates) define the application and supporting services:

- Frontend deployment and service
- Backend deployment and service
- Ingress routing
- HPA
- App config and secrets
- Logging resources

Useful checks after deployment:

```powershell
kubectl get svc
kubectl get pods
kubectl get all
```

## 13. Verification Checklist

Use this checklist to confirm the lab is working:

- `vagrant up` completes without errors
- `lb1` serves the frontend through Nginx
- `app1` runs k3s and exposes the backend service
- Images are pushed to the local registry on `cicd1`
- Prometheus and Grafana are reachable on `mon1`
- Elasticsearch and Kibana are reachable on `mon1`
- Backup jobs are scheduled on `backup1`

## 14. Troubleshooting

### Load balancer not responding

Check Nginx on `lb1`:

```bash
sudo systemctl status nginx
sudo nginx -t
```

### Kubernetes pods not starting

Check k3s on `app1`:

```bash
sudo systemctl status k3s
sudo k3s kubectl get pods -A
```

### Registry push failures

Check the registry on `cicd1`:

```bash
curl -s http://192.168.56.15:5000/v2/
```

### Monitoring dashboards are empty

Check the monitoring stack on `mon1` and confirm the scrape targets are reachable from the VM network.

### Backup issues

Check the backup timer and logs on `backup1`:

```bash
systemctl status weekly-backup.timer
journalctl -u weekly-backup.service --no-pager
```

## 15. Resetting the Lab

To rebuild the environment from scratch:

```powershell
vagrant destroy -f
vagrant up
```

This is the fastest way to recover from a broken local state.
