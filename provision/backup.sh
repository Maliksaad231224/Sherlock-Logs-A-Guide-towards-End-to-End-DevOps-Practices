set -e

VM_NAME="$1"
DEVOPS_USER="devops"

echo ">>> [${VM_NAME}] Backup VM provisioning (rsync) starting..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y rsync openssh-client

BACKUP_ROOT="/var/backups/sherlock-logs"
mkdir -p "$BACKUP_ROOT"
chmod 750 "$BACKUP_ROOT"

BACKUP_KEY_DIR="/home/${DEVOPS_USER}/.ssh"
BACKUP_KEY="${BACKUP_KEY_DIR}/backup_rsync_ed25519"
PUB_EXPORT="/vagrant/backup_devops_authorized_keys"

mkdir -p "$BACKUP_KEY_DIR"
chmod 700 "$BACKUP_KEY_DIR"
chown -R "${DEVOPS_USER}:${DEVOPS_USER}" "$BACKUP_KEY_DIR"

if [ ! -f "$BACKUP_KEY" ]; then
  echo ">>> Generating dedicated backup SSH keypair..."
  sudo -u "${DEVOPS_USER}" ssh-keygen -t ed25519 -N "" -f "$BACKUP_KEY" -C "backup1-rsync"
fi

echo ">>> Exporting backup public key to ${PUB_EXPORT} ..."
cat "${BACKUP_KEY}.pub" > "${PUB_EXPORT}"
chmod 644 "${PUB_EXPORT}"

SSH_CFG="${BACKUP_KEY_DIR}/config"
if ! grep -q "Host 192.168.56." "$SSH_CFG" 2>/dev/null; then
  cat >>"$SSH_CFG" <<EOF

Host 192.168.56.*
  User ${DEVOPS_USER}
  IdentityFile ${BACKUP_KEY}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
  chown "${DEVOPS_USER}:${DEVOPS_USER}" "$SSH_CFG"
  chmod 600 "$SSH_CFG"
fi

cat >/usr/local/bin/weekly-backup.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

DEVOPS_USER="devops"
BACKUP_ROOT="/var/backups/sherlock-logs"
DATE="$(date +%F)"

TARGETS=(
  "lb1:192.168.56.10"
  "web1:192.168.56.11"
  "web2:192.168.56.12"
  "app1:192.168.56.13"
)

BACKUP_PATHS=(
  "/etc"
  "/home/devops"
  "/home/devops/sherlock-logs"
  "/var/lib/docker/volumes"
)

log() { echo "[$(date -Is)] $*"; }

for t in "${TARGETS[@]}"; do
  NAME="${t%%:*}"
  IP="${t##*:}"

  DEST="${BACKUP_ROOT}/${NAME}/${DATE}"
  mkdir -p "$DEST"
  chmod 750 "$DEST"

  log "=== Backing up ${NAME} (${IP}) to ${DEST} ==="

  for P in "${BACKUP_PATHS[@]}"; do
    if [[ "$P" == "/var/lib/docker/volumes" ]]; then
      if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${DEVOPS_USER}@${IP}" "sudo test -d /var/lib/docker/volumes"; then
        log "Skip ${NAME}:${P} (not present)"
        continue
      fi
    fi

    SAFE_PATH="$(echo "$P" | sed 's#^/##; s#/#_#g')"
    SUBDEST="${DEST}/${SAFE_PATH}"
    mkdir -p "$SUBDEST"

    log "rsync ${NAME}:${P} -> ${SUBDEST}"

    rsync -aHAX --numeric-ids --delete \
      -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
      --rsync-path="sudo rsync" \
      "${DEVOPS_USER}@${IP}:${P}/" \
      "${SUBDEST}/"
  done

  log "Completed ${NAME}"
done

log "All backups completed successfully."
EOF

chmod +x /usr/local/bin/weekly-backup.sh

cat >/usr/local/bin/restore-from-backup.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: restore-from-backup.sh <host> <date YYYY-mm-dd> <path>"
  echo "Example: restore-from-backup.sh web1 2026-01-22 /etc"
  exit 1
fi

HOST="$1"
DATE="$2"
RESTORE_PATH="$3"

declare -A IPS=(
  ["lb1"]="192.168.56.10"
  ["web1"]="192.168.56.11"
  ["web2"]="192.168.56.12"
  ["app1"]="192.168.56.13"
)

IP="${IPS[$HOST]:-}"
if [ -z "$IP" ]; then
  echo "Unknown host: $HOST (allowed: lb1, web1, web2, app1)"
  exit 1
fi

SAFE_PATH="$(echo "$RESTORE_PATH" | sed 's#^/##; s#/#_#g')"
SRC="/var/backups/sherlock-logs/${HOST}/${DATE}/${SAFE_PATH}"

if [ ! -d "$SRC" ]; then
  echo "Backup snapshot not found: $SRC"
  exit 1
fi

echo "Restoring ${RESTORE_PATH} to ${HOST} (${IP}) from ${SRC}"
echo "This will overwrite remote content to match the backup snapshot."

rsync -aHAX --numeric-ids --delete \
  -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  --rsync-path="sudo rsync" \
  "${SRC}/" \
  "devops@${IP}:${RESTORE_PATH}/"

echo "Restore complete."
EOF

chmod +x /usr/local/bin/restore-from-backup.sh

cat >/etc/systemd/system/weekly-backup.service <<'EOF'
[Unit]
Description=Weekly full backup (rsync pull) of infrastructure nodes

[Service]
Type=oneshot
ExecStart=/usr/local/bin/weekly-backup.sh
EOF

cat >/etc/systemd/system/weekly-backup.timer <<'EOF'
[Unit]
Description=Run weekly backup every Sunday at 02:00

[Timer]
OnCalendar=Sun *-*-* 02:00:00
Persistent=true
Unit=weekly-backup.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now weekly-backup.timer

echo ">>> [${VM_NAME}] Backup VM provisioning complete."
echo ">>> Public key exported to /vagrant/backup_devops_authorized_keys"
echo ">>> Next: reprovision lb1/web1/web2/app1 so base.sh appends this key."