set -euo pipefail

VM_NAME="${1:-node}"

echo ">>> [${VM_NAME}] Docker provisioning starting..."
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable
EOF

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl restart docker

usermod -aG docker devops >/dev/null 2>&1 || true

mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<'EOF'
{
  "insecure-registries": ["192.168.56.15:5000"]
}
EOF

systemctl restart docker

curl -fsS --max-time 2 http://192.168.56.15:5000/v2/ >/dev/null 2>&1 || true

echo ">>> [${VM_NAME}] Docker provisioning complete."