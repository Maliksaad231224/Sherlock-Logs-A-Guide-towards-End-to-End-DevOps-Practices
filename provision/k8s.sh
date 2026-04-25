set -euo pipefail

VM_NAME="${1:-app1}"
DEVOPS_USER="devops"
SUBNET="192.168.56.0/24"

echo ">>> [${VM_NAME}] Kubernetes (k3s) provisioning starting..."
export DEBIAN_FRONTEND=noninteractive

mkdir -p /etc/rancher/k3s
cat >/etc/rancher/k3s/registries.yaml <<'EOF'
mirrors:
  "192.168.56.15:5000":
    endpoint:
      - "http://192.168.56.15:5000"
configs:
  "192.168.56.15:5000":
    tls:
      insecure_skip_verify: true
EOF

if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
else
  systemctl restart k3s
fi

systemctl enable --now k3s

for i in $(seq 1 60); do
  if k3s kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

k3s kubectl get nodes >/dev/null 2>&1

install -d -m 700 -o "${DEVOPS_USER}" -g "${DEVOPS_USER}" "/home/${DEVOPS_USER}/.kube"
cp /etc/rancher/k3s/k3s.yaml "/home/${DEVOPS_USER}/.kube/config"
sed -i 's/127.0.0.1/192.168.56.13/' "/home/${DEVOPS_USER}/.kube/config"
chown "${DEVOPS_USER}:${DEVOPS_USER}" "/home/${DEVOPS_USER}/.kube/config"
chmod 600 "/home/${DEVOPS_USER}/.kube/config"

if [ ! -f /usr/local/bin/kubectl ]; then
  cat >/usr/local/bin/kubectl <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/k3s kubectl "$@"
EOF
  chmod +x /usr/local/bin/kubectl
fi

ufw allow from ${SUBNET} to any port 6443 proto tcp >/dev/null 2>&1 || true
ufw allow from ${SUBNET} to any port 30007 proto tcp >/dev/null 2>&1 || true

echo ">>> [${VM_NAME}] Kubernetes (k3s) provisioning complete."
