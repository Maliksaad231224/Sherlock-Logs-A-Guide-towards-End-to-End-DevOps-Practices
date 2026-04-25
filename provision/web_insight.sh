set -euo pipefail

VM_NAME="$1"
DEVOPS_USER="devops"

echo ">>> [${VM_NAME}] Sherlock Logs FRONTEND provisioning..."

export DEBIAN_FRONTEND=noninteractive

REGISTRY="192.168.56.15:5000"
IMAGE_NAME="sherlock-logs-frontend"
IMAGE_TAG="prod"

apt-get update -y
apt-get install -y nginx
systemctl enable --now nginx

SRC_DIR="/vagrant/frontend"
DEST_DIR="/home/${DEVOPS_USER}/sherlock-logs/frontend"

if [ ! -d "$SRC_DIR" ]; then
  echo "ERROR: $SRC_DIR not found. Expected frontend/ at repo root (same level as Vagrantfile)."
  exit 1
fi

mkdir -p "$DEST_DIR"
rsync -a --delete "$SRC_DIR/" "$DEST_DIR/"
chown -R "${DEVOPS_USER}:${DEVOPS_USER}" "/home/${DEVOPS_USER}/sherlock-logs"

cd "$DEST_DIR"

echo ">>> [${VM_NAME}] Building frontend Docker image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo ">>> [${VM_NAME}] Tagging frontend image for registry ${REGISTRY}..."
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo ">>> [${VM_NAME}] Pushing frontend image to registry..."
docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

APP_DIR="/opt/sherlock-logs"
mkdir -p "$APP_DIR"

cat >"${APP_DIR}/docker-compose.yml" <<EOF
services:
  frontend:
    image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
    container_name: infra-frontend
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:80"
EOF

rm -f /etc/nginx/sites-enabled/default || true

cat >/etc/nginx/sites-available/insight.conf <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    add_header X-Served-By $hostname always;

    location / {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api/ {
        proxy_pass http://192.168.56.13:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/insight.conf /etc/nginx/sites-enabled/insight.conf

nginx -t
systemctl restart nginx

bash /vagrant/provision/deploy_helper.sh
sudo /usr/local/bin/sherlock-logs-deploy web

echo ">>> [${VM_NAME}] Frontend served on port 80. Backend proxied via /api/"
echo ">>> [${VM_NAME}] Sherlock Logs FRONTEND provisioning complete."