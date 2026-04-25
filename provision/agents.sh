set -euo pipefail

VM_NAME="$1"
MON_IP="192.168.56.16"
SUBNET="192.168.56.0/24"

echo ">>> [${VM_NAME}] Observability agents provisioning..."
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl gnupg ca-certificates apt-transport-https


apt-get install -y prometheus-node-exporter

DEFAULT_FILE="/etc/default/prometheus-node-exporter"
if [ -f "$DEFAULT_FILE" ]; then
  if ! grep -q -- "--web.listen-address" "$DEFAULT_FILE"; then
    echo 'ARGS="--web.listen-address=0.0.0.0:9100"' >> "$DEFAULT_FILE"
  else
    sed -i 's/--web.listen-address=[^ ]\+/--web.listen-address=0.0.0.0:9100/g' "$DEFAULT_FILE" || true
  fi
fi

systemctl enable --now prometheus-node-exporter
ufw allow from ${SUBNET} to any port 9100 proto tcp >/dev/null 2>&1 || true

if command -v docker >/dev/null 2>&1; then
  echo ">>> [${VM_NAME}] Docker detected - enabling cAdvisor"

  docker rm -f cadvisor >/dev/null 2>&1 || true
  docker run -d \
    --name=cadvisor \
    --restart=unless-stopped \
    -p 8080:8080 \
    -v /:/rootfs:ro \
    -v /var/run:/var/run:ro \
    -v /sys:/sys:ro \
    -v /var/lib/docker/:/var/lib/docker:ro \
    gcr.io/cadvisor/cadvisor:v0.49.1 >/dev/null

  ufw allow from ${MON_IP} to any port 8080 proto tcp >/dev/null 2>&1 || true
fi

if ! dpkg -s filebeat >/dev/null 2>&1; then
  echo ">>> [${VM_NAME}] Installing Filebeat from Elastic repo"

  sudo mkdir -p /usr/share/keyrings

  # (Re)install correct Elastic GPG key into a dedicated keyring
  curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/elastic-archive-keyring.gpg

  # Ensure the repo uses the same keyring via signed-by=
  echo "deb [signed-by=/usr/share/keyrings/elastic-archive-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
    | sudo tee /etc/apt/sources.list.d/elastic-8.x.list > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y filebeat
fi

mkdir -p /etc/filebeat

cat > /etc/filebeat/filebeat.yml <<EOFYAML
filebeat.inputs:
  - type: filestream
    id: syslog
    enabled: true
    paths:
      - /var/log/syslog
      - /var/log/auth.log

  - type: filestream
    id: nginx
    enabled: true
    paths:
      - /var/log/nginx/access.log
      - /var/log/nginx/error.log
    ignore_older: 72h

  - type: filestream
    id: docker
    enabled: true
    paths:
      - /var/lib/docker/containers/*/*.log
    parsers:
      - ndjson:
          target: "docker"
          add_error_key: true
          overwrite_keys: true
    processors:
      - add_fields:
          target: ""
          fields:
            log_source: docker

  - type: filestream
    id: k8s
    enabled: true
    paths:
      - /var/log/containers/*.log
    processors:
      - add_fields:
          target: ""
          fields:
            log_source: k8s

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_fields:
      target: ""
      fields:
        env: lab

output.logstash:
  hosts: ["${MON_IP}:5044"]

setup.ilm.enabled: false
EOFYAML

systemctl enable --now filebeat
systemctl restart filebeat

echo ">>> [${VM_NAME}] Observability agents provisioning complete."