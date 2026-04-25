curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
kubectl get nodes
kubectl get svc
sudo sed -i 's/127.0.0.1/192.168.56.10/g' ~/.kube/config

sudo mkdir -p /etc/rancher/k3s && \
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

sudo systemctl restart docker

