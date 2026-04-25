set -euo pipefail

VM_NAME="$1"
DEVOPS_USER="devops"

echo ">>> [${VM_NAME}] Sherlock-Logs BACKEND provisioning..."

export DEBIAN_FRONTEND=noninteractive

REGISTRY="192.168.56.15:5000"
IMAGE_NAME="sherlock-logs-backend"
IMAGE_TAG="prod"

systemctl stop app1.service 2>/dev/null || true
systemctl disable app1.service 2>/dev/null || true
systemctl stop app1-health.timer 2>/dev/null || true
systemctl disable app1-health.timer 2>/dev/null || true

SRC_DIR="/vagrant/backend"
DEST_DIR="/home/${DEVOPS_USER}/sherlock-logs/backend"

if [ ! -d "$SRC_DIR" ]; then
  echo "ERROR: $SRC_DIR not found. Expected backend/ at repo root (same level as Vagrantfile)."
  exit 1
fi

mkdir -p "$DEST_DIR"
rsync -a --delete "$SRC_DIR/" "$DEST_DIR/"
chown -R "${DEVOPS_USER}:${DEVOPS_USER}" "/home/${DEVOPS_USER}/sherlock-logs"

cd "$DEST_DIR"

echo ">>> [${VM_NAME}] Building backend Docker image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo ">>> [${VM_NAME}] Tagging backend image for registry ${REGISTRY}..."
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo ">>> [${VM_NAME}] Pushing backend image to registry..."
docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

APP_DIR="/opt/sherlock-logs"
mkdir -p "$APP_DIR"

cat >"${APP_DIR}/docker-compose.yml" <<EOF
services:
  backend:
    image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
    container_name: automation-backend
    restart: unless-stopped
    ports:
      - "5000:5000"
EOF

bash /vagrant/provision/deploy_helper.sh
sudo /usr/local/bin/sherlock-logs-deploy app

echo ">>> [${VM_NAME}] Backend deployed via compose at http://0.0.0.0:5000/metrics-json"
echo ">>> [${VM_NAME}] Sherlock Logs BACKEND provisioning complete."