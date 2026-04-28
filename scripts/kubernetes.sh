#!/bin/bash

set -e


curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -


mkdir -p ~/.kube

sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

export KUBECONFIG=~/.kube/config

sudo sed -i 's/127.0.0.1/192.168.56.10/g' ~/.kube/config


kubectl get nodes
kubectl get svc


sudo mkdir -p /etc/rancher/k3s

sudo tee /etc/rancher/k3s/registries.yaml > /dev/null <<EOF
mirrors:
  "localhost:5000":
    endpoint:
      - "http://192.168.56.15:5000"
EOF


sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": [
    "192.168.56.15:5000"
  ]
}
EOF

sudo systemctl restart docker || true

echo "✅ K3s setup completed successfully"