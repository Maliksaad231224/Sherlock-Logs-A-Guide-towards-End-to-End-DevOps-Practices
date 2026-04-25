set -euo pipefail

VM_NAME="${1:-cicd1}"
DEVOPS_USER="devops"

echo ">>> [${VM_NAME}] CI/CD provisioning starting..."
export DEBIAN_FRONTEND=noninteractive

REGISTRY_PORT="5000"
GITEA_PORT="3000"
GITEA_SSH_PORT="2222"
GITEA_IP="192.168.56.15"
GITEA_URL="http://${GITEA_IP}:${GITEA_PORT}"

GITEA_ADMIN_USER="gitea-admin"
GITEA_ADMIN_PASS="Admin_1234!"
GITEA_ADMIN_EMAIL="admin@local.lab"

log(){ echo "[$(date -Is)] $*"; }

usermod -aG docker "$DEVOPS_USER" >/dev/null 2>&1 || true

ufw allow from 192.168.56.0/24 to any port "${REGISTRY_PORT}" proto tcp >/dev/null 2>&1 || true
ufw allow from 192.168.56.0/24 to any port "${GITEA_PORT}" proto tcp >/dev/null 2>&1 || true
ufw allow from 192.168.56.0/24 to any port "${GITEA_SSH_PORT}" proto tcp >/dev/null 2>&1 || true

log "Setting up local Docker registry..."
mkdir -p /opt/registry/data

cat >/opt/registry/docker-compose.yml <<EOF
services:
  registry:
    image: registry:2
    container_name: local_registry
    restart: unless-stopped
    ports:
      - "${REGISTRY_PORT}:5000"
    environment:
      - REGISTRY_STORAGE_DELETE_ENABLED=true
    volumes:
      - /opt/registry/data:/var/lib/registry
EOF

docker compose -f /opt/registry/docker-compose.yml up -d

log "Waiting for registry..."
for i in $(seq 1 30); do
  if curl -fsS --max-time 2 "http://127.0.0.1:${REGISTRY_PORT}/v2/" >/dev/null; then
    log "Registry OK."
    break
  fi
  sleep 2
done
curl -fsS --max-time 2 "http://127.0.0.1:${REGISTRY_PORT}/v2/" >/dev/null \
  || { log "ERROR: Registry not ready"; docker logs local_registry || true; exit 1; }

log "Setting up Gitea..."
mkdir -p /opt/gitea/data
chown -R 1000:1000 /opt/gitea/data
chmod -R 755 /opt/gitea/data

cat >/opt/gitea/docker-compose.yml <<EOF
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea_server
    restart: unless-stopped
    ports:
      - "${GITEA_PORT}:3000"
      - "${GITEA_SSH_PORT}:22"
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__server__DOMAIN=${GITEA_IP}
      - GITEA__server__ROOT_URL=${GITEA_URL}/
      - GITEA__server__SSH_DOMAIN=${GITEA_IP}
      - GITEA__server__SSH_PORT=${GITEA_SSH_PORT}
      - GITEA__actions__ENABLED=true
      - GITEA__service__DISABLE_REGISTRATION=true
      - GITEA__security__INSTALL_LOCK=true
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__database__PATH=/data/gitea/gitea.db
    volumes:
      - /opt/gitea/data:/data
EOF

docker compose -f /opt/gitea/docker-compose.yml up -d

log "Waiting for Gitea HTTP..."
for i in $(seq 1 90); do
  if curl -fsS --max-time 2 "http://127.0.0.1:${GITEA_PORT}/" >/dev/null; then
    log "Gitea HTTP OK."
    break
  fi
  sleep 2
done
curl -fsS --max-time 2 "http://127.0.0.1:${GITEA_PORT}/" >/dev/null \
  || { log "ERROR: Gitea not ready"; docker logs gitea_server --tail 200 || true; exit 1; }

log "Waiting for Gitea app.ini..."
for i in $(seq 1 60); do
  if docker exec -u git gitea_server test -f /data/gitea/conf/app.ini 2>/dev/null; then
    log "Gitea app.ini exists."
    break
  fi
  sleep 2
done
docker exec -u git gitea_server test -f /data/gitea/conf/app.ini \
  || { log "ERROR: /data/gitea/conf/app.ini missing"; docker logs gitea_server --tail 200 || true; exit 1; }

log "Creating Gitea admin user (idempotent)..."
set +e
docker exec -u git gitea_server gitea admin user create \
  --username "${GITEA_ADMIN_USER}" \
  --password "${GITEA_ADMIN_PASS}" \
  --email "${GITEA_ADMIN_EMAIL}" \
  --admin \
  --must-change-password=false >/dev/null 2>&1
set -e

echo "${GITEA_URL}" > /vagrant/act_runner.url
chmod 644 /vagrant/act_runner.url

log "Generating runner registration token via Gitea..."
RUNNER_TOKEN="$(docker exec -u git gitea_server gitea actions generate-runner-token | tail -n1 | tr -d '\r\n')"
if [ -z "${RUNNER_TOKEN}" ]; then
  log "ERROR: runner token generation returned empty"
  exit 1
fi
echo "${RUNNER_TOKEN}" > /vagrant/act_runner.token
chmod 644 /vagrant/act_runner.token
log "Runner token generated and exported to /vagrant/act_runner.token"

log "Generating CI deploy SSH keypair (idempotent)..."
mkdir -p /opt/act_runner/ssh
chmod 700 /opt/act_runner/ssh

DEPLOY_KEY="/opt/act_runner/ssh/deploy_ed25519"
DEPLOY_PUB="${DEPLOY_KEY}.pub"

if [ ! -f "$DEPLOY_KEY" ]; then
  ssh-keygen -t ed25519 -N "" -f "$DEPLOY_KEY" -C "cicd1-deploy@sherlock-logs" >/dev/null
  chmod 600 "$DEPLOY_KEY"
  chmod 644 "$DEPLOY_PUB"
fi

cp -f "$DEPLOY_PUB" /vagrant/cicd_deploy.pub
chmod 644 /vagrant/cicd_deploy.pub
log "Exported CI deploy public key to /vagrant/cicd_deploy.pub"

log "Starting act_runner..."
mkdir -p /opt/act_runner/data

docker rm -f gitea_act_runner >/dev/null 2>&1 || true
rm -rf /opt/act_runner/data/*

cat >/opt/act_runner/runner.env <<EOF
GITEA_INSTANCE_URL=${GITEA_URL}
GITEA_RUNNER_REGISTRATION_TOKEN=${RUNNER_TOKEN}
GITEA_RUNNER_NAME=cicd1-runner
GITEA_RUNNER_LABELS=ubuntu-latest:docker://node:20-bookworm,linux:docker://alpine:3.20
EOF

cat >/opt/act_runner/docker-compose.yml <<'EOF'
services:
  act_runner:
    image: gitea/act_runner:latest
    container_name: gitea_act_runner
    restart: unless-stopped
    env_file:
      - /opt/act_runner/runner.env
    volumes:
      - /opt/act_runner/data:/data
      - /opt/act_runner/ssh:/data/ssh:ro
      - /var/run/docker.sock:/var/run/docker.sock
EOF

docker compose -f /opt/act_runner/docker-compose.yml up -d

log "Runner log (tail):"
docker logs gitea_act_runner --tail 80 || true

log "CI/CD provisioning complete."
log "Gitea:    ${GITEA_URL}"
log "Registry: http://${GITEA_IP}:${REGISTRY_PORT}"
log "Runner:   gitea_act_runner"
log "Exported: /vagrant/act_runner.url /vagrant/act_runner.token /vagrant/cicd_deploy.pub"