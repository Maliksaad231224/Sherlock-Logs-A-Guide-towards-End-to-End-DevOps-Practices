set -euo pipefail

cat >/usr/local/bin/sherlock-logs-deploy <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-unknown}" # app or web
APP_DIR="/opt/sherlock-logs"
COMPOSE="${APP_DIR}/docker-compose.yml"
STATE_DIR="${APP_DIR}/state"
LOG_FILE="/var/log/sherlock-logs-deploy.log"

log() {
  local msg="[$(date -Is)] $*"
  echo "$msg"
  sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "$msg" | sudo tee -a "$LOG_FILE" >/dev/null || true
}

die() {
  log "ERROR: $*"
  exit 1
}

[ -f "$COMPOSE" ] || die "$COMPOSE not found"

mkdir -p "$STATE_DIR"

MAP_SERVICES="${STATE_DIR}/services_images.map"
MAP_PREVIOUS="${STATE_DIR}/previous_images.map"
LAST_GOOD="${STATE_DIR}/last_good.txt"

: > "$MAP_SERVICES"
: > "$MAP_PREVIOUS"

log "=== sherlock-logs-deploy START role=${ROLE} ==="
log "Using compose file: $COMPOSE"

log "Extracting service image refs from docker compose config..."

current_service=""
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
    current_service="${BASH_REMATCH[1]}"
    continue
  fi

  if [[ -n "$current_service" && "$line" =~ ^[[:space:]]{4}image:[[:space:]]+(.+)[[:space:]]*$ ]]; then
    image_ref="${BASH_REMATCH[1]}"
    echo "${current_service} ${image_ref}" >> "$MAP_SERVICES"
  fi
done < <(docker compose -f "$COMPOSE" config)

if [ ! -s "$MAP_SERVICES" ]; then
  die "Could not determine services/images from compose. Check compose syntax."
fi

log "Service image refs:"
while read -r svc img; do
  log "  - ${svc} -> ${img}"
done < "$MAP_SERVICES"

log "Capturing currently running image IDs (pre-pull) for rollback..."
while read -r svc img_ref; do
  cid="$(docker compose -f "$COMPOSE" ps -q "$svc" 2>/dev/null || true)"
  if [ -n "${cid:-}" ]; then
    img_id="$(docker inspect -f '{{.Image}}' "$cid" 2>/dev/null || true)"
    if [ -n "${img_id:-}" ]; then
      echo "${svc} ${img_ref} ${img_id}" >> "$MAP_PREVIOUS"
      log "  - ${svc}: container=${cid} image_id=${img_id}"
    else
      log "  - ${svc}: WARNING could not read image id for container=${cid}"
    fi
  else
    log "  - ${svc}: no running container (first deploy or stopped)"
  fi
done < "$MAP_SERVICES"

log "Pulling images..."
docker compose -f "$COMPOSE" pull

log "Restarting services..."
docker compose -f "$COMPOSE" up -d

healthcheck_ok="false"

if [ "$ROLE" = "app" ]; then
  log "Healthcheck backend: http://127.0.0.1:5000/health"
  for i in $(seq 1 20); do
    if curl -fsS --max-time 2 http://127.0.0.1:5000/health >/dev/null; then
      healthcheck_ok="true"
      break
    fi
    sleep 2
  done
elif [ "$ROLE" = "web" ]; then
  log "Healthcheck frontend: http://127.0.0.1/"
  for i in $(seq 1 20); do
    if curl -fsS --max-time 2 http://127.0.0.1/ >/dev/null; then
      healthcheck_ok="true"
      break
    fi
    sleep 2
  done
else
  die "ROLE must be 'app' or 'web' (got: $ROLE)"
fi

if [ "$healthcheck_ok" = "true" ]; then
  log "Deploy success"

  log "Recording last-good state..."
  {
    echo "timestamp=$(date -Is)"
    echo "role=${ROLE}"
    echo "compose=${COMPOSE}"
    echo "services:"
    while read -r svc img_ref; do
      cid="$(docker compose -f "$COMPOSE" ps -q "$svc" 2>/dev/null || true)"
      img_id=""
      if [ -n "${cid:-}" ]; then
        img_id="$(docker inspect -f '{{.Image}}' "$cid" 2>/dev/null || true)"
      fi
      echo "  - ${svc} image_ref=${img_ref} image_id=${img_id}"
    done < "$MAP_SERVICES"
  } > "$LAST_GOOD"

  log "=== sherlock-logs-deploy END (SUCCESS) ==="
  exit 0
fi

log "Healthcheck FAILED - initiating rollback"

if [ ! -s "$MAP_PREVIOUS" ]; then
  log "No previous images captured (first deploy). Rolling back not possible."
  log "=== sherlock-logs-deploy END (FAIL) ==="
  exit 1
fi

log "Stopping current services..."
docker compose -f "$COMPOSE" down || true

log "Re-tagging previous images back to expected compose image refs..."
while read -r svc img_ref img_id; do
  if docker image inspect "$img_id" >/dev/null 2>&1; then
    log "  - docker tag ${img_id} ${img_ref}"
    docker tag "$img_id" "$img_ref"
  else
    log "  - WARNING: previous image id not present locally: ${img_id} (svc=${svc})"
  fi
done < "$MAP_PREVIOUS"

log "Starting services after rollback (no pull)..."
docker compose -f "$COMPOSE" up -d --no-build

rollback_ok="false"
if [ "$ROLE" = "app" ]; then
  for i in $(seq 1 10); do
    if curl -fsS --max-time 2 http://127.0.0.1:5000/health >/dev/null; then
      rollback_ok="true"
      break
    fi
    sleep 2
  done
else
  for i in $(seq 1 10); do
    if curl -fsS --max-time 2 http://127.0.0.1/ >/dev/null; then
      rollback_ok="true"
      break
    fi
    sleep 2
  done
fi

if [ "$rollback_ok" = "true" ]; then
  log "Rollback success (service restored)"
  log "=== sherlock-logs-deploy END (ROLLBACK-SUCCESS) ==="
  exit 1
fi

log "Rollback attempted but healthcheck still failing"
log "=== sherlock-logs-deploy END (ROLLBACK-FAIL) ==="
exit 1
EOF

chmod +x /usr/local/bin/sherlock-logs-deploy