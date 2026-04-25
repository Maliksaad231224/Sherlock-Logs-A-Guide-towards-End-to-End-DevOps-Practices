set -euo pipefail

VM_NAME="$1"
LAB_MODE="${2:-compact}"
SUBNET="192.168.56.0/24"

if [ "${LAB_MODE}" = "full" ]; then
  NODE_TARGETS="          - '192.168.56.10:9100' # lb1
    - '192.168.56.11:9100' # web1
    - '192.168.56.12:9100' # web2
    - '192.168.56.13:9100' # app1
    - '192.168.56.14:9100' # backup1
    - '192.168.56.15:9100' # cicd1
    - '192.168.56.16:9100' # mon1"
  CADVISOR_TARGETS="          - '192.168.56.11:8080' # web1
    - '192.168.56.12:8080' # web2
    - '192.168.56.13:8080' # app1
    - '192.168.56.15:8080' # cicd1"
else
  NODE_TARGETS="          - '192.168.56.13:9100' # app1
    - '192.168.56.15:9100' # cicd1
    - '192.168.56.16:9100' # mon1"
  CADVISOR_TARGETS="          - '192.168.56.13:8080' # app1
    - '192.168.56.15:8080' # cicd1"
fi

echo ">>> [${VM_NAME}] Monitoring+Logging (Prometheus/Grafana + ELK) provisioning..."
export DEBIAN_FRONTEND=noninteractive

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not installed"; exit 1; }
docker version >/dev/null

ufw allow from ${SUBNET} to any port 9090 proto tcp >/dev/null 2>&1 || true  # Prometheus
ufw allow from ${SUBNET} to any port 3000 proto tcp >/dev/null 2>&1 || true  # Grafana
ufw allow from ${SUBNET} to any port 5601 proto tcp >/dev/null 2>&1 || true  # Kibana
ufw allow from ${SUBNET} to any port 9200 proto tcp >/dev/null 2>&1 || true  # Elasticsearch
ufw allow from ${SUBNET} to any port 5044 proto tcp >/dev/null 2>&1 || true  # Logstash beats

BASE_DIR="/opt/observability"
PROM_DIR="${BASE_DIR}/prometheus"
GRAF_DIR="${BASE_DIR}/grafana"
AM_DIR="${BASE_DIR}/alertmanager"
LS_DIR="${BASE_DIR}/logstash"

mkdir -p "${PROM_DIR}" "${GRAF_DIR}/provisioning/datasources" "${GRAF_DIR}/provisioning/dashboards" \
         "${GRAF_DIR}/dashboards" "${AM_DIR}" "${LS_DIR}/pipeline"

cat > "${PROM_DIR}/prometheus.yml" <<YAML
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

rule_files:
  - /etc/prometheus/rules.yml

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'node'
    static_configs:
      - targets:
${NODE_TARGETS}

  - job_name: 'cadvisor'
    scrape_interval: 15s
    static_configs:
      - targets:
${CADVISOR_TARGETS}

  - job_name: 'sherlock-backend'
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.56.13:30050']

  - job_name: 'elasticsearch-exporter'
    static_configs:
      - targets: ['elasticsearch-exporter:9114']
YAML

cat > "${PROM_DIR}/rules.yml" <<'YAML'
groups:
  - name: vm.rules
    rules:
      - alert: VMUnreachable
        expr: up{job="node"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "VM unreachable"
          description: "Node exporter is down for {{ $labels.instance }}"

      - alert: HighCPUUsage
        expr: (1 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 0.80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU > 80% for 5m on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "RAM > 90% for 5m on {{ $labels.instance }}"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) < 0.20
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space"
          description: "Disk free < 20% on {{ $labels.instance }} (mount={{ $labels.mountpoint }})"

  - name: docker.rules
    rules:
      - alert: ContainerRestartsHigh
        expr: changes(container_start_time_seconds{container_label_com_docker_compose_service!=""}[15m]) > 3
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Container restarts high"
          description: "More than 3 restarts in 15m ({{ $labels.instance }} service={{ $labels.container_label_com_docker_compose_service }})"

      - alert: ContainerMemoryHigh
        expr: (container_memory_usage_bytes{container_label_com_docker_compose_service!=""} / clamp_min(container_spec_memory_limit_bytes{container_label_com_docker_compose_service!=""}, 1)) > 0.80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container memory usage high"
          description: "Memory > 80% of limit for 5m ({{ $labels.instance }} service={{ $labels.container_label_com_docker_compose_service }})"

  - name: elastic.rules
    rules:
      - alert: ElasticsearchClusterNotGreen
        expr: elasticsearch_cluster_health_status{color!="green"} == 1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Elasticsearch cluster not green"
          description: "Cluster health is {{ $labels.color }}"

  - name: advanced.rules
    rules:
      - alert: CPUTrendUp
        expr: (1 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])))
              >
              ((1 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[1h]))) + 0.10)
        for: 10m
        labels:
          severity: info
        annotations:
          summary: "CPU trending up"
          description: "CPU usage on {{ $labels.instance }} is increasing steadily."

      - alert: CPUHighAndMemoryLow
        expr: (1 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 0.85
              and
              (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "CPU high and memory low"
          description: "High CPU + low available memory on {{ $labels.instance }}"
YAML

cat > "${AM_DIR}/alertmanager.yml" <<'YAML'
global:
  resolve_timeout: 5m

route:
  receiver: 'webhook'
  group_by: ['alertname', 'instance']
  group_wait: 15s
  group_interval: 2m
  repeat_interval: 2h

receivers:
  - name: 'webhook'
    webhook_configs:
      - url: 'http://alert-webhook:5001/alert'
        send_resolved: true
YAML

cat > "${LS_DIR}/pipeline/logstash.conf" <<'CONF'
input {
  beats {
    port => 5044
  }
}

filter {
  if [docker][log] {
    json {
      source => "[docker][log]"
      target => "app"
      skip_on_invalid_json => true
    }
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug { metadata => false } }
}
CONF

cat > "${GRAF_DIR}/provisioning/datasources/ds.yml" <<'YAML'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
YAML

cat > "${GRAF_DIR}/provisioning/dashboards/dashboards.yml" <<'YAML'
apiVersion: 1

dashboards:
  - name: 'sherlock-dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
YAML

cat > "${GRAF_DIR}/dashboards/vm-performance.json" <<'JSON'
{
  "uid": "vm-perf",
  "title": "VM Performance",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "15s",
  "panels": [
    {
      "type": "timeseries",
      "title": "CPU usage %",
      "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
      "targets": [
        {"expr": "(1 - avg by(instance)(rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))) * 100", "legendFormat": "{{instance}}"}
      ]
    },
    {
      "type": "timeseries",
      "title": "Memory used %",
      "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
      "targets": [
        {"expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100", "legendFormat": "{{instance}}"}
      ]
    },
    {
      "type": "timeseries",
      "title": "Disk free % (non-tmpfs)",
      "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
      "targets": [
        {"expr": "(node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"}) * 100", "legendFormat": "{{instance}} {{mountpoint}}"}
      ]
    },
    {
      "type": "timeseries",
      "title": "Network receive (bytes/s)",
      "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8},
      "targets": [
        {"expr": "rate(node_network_receive_bytes_total{device!~\"lo\"}[5m])", "legendFormat": "{{instance}} {{device}}"}
      ]
    }
  ]
}
JSON

cat > "${GRAF_DIR}/dashboards/docker-containers.json" <<'JSON'
{
  "uid": "docker",
  "title": "Docker Containers",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "15s",
  "panels": [
    {
      "type": "timeseries",
      "title": "Container CPU (cores)",
      "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
      "targets": [
        {"expr": "rate(container_cpu_usage_seconds_total{container_label_com_docker_compose_service!=\"\"}[1m])", "legendFormat": "{{instance}} {{container_label_com_docker_compose_service}}"}
      ]
    },
    {
      "type": "timeseries",
      "title": "Container memory usage (bytes)",
      "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
      "targets": [
        {"expr": "container_memory_usage_bytes{container_label_com_docker_compose_service!=\"\"}", "legendFormat": "{{instance}} {{container_label_com_docker_compose_service}}"}
      ]
    },
    {
      "type": "timeseries",
      "title": "Restart count (changes in start time / 15m)",
      "gridPos": {"x": 0, "y": 8, "w": 24, "h": 8},
      "targets": [
        {"expr": "changes(container_start_time_seconds{container_label_com_docker_compose_service!=\"\"}[15m])", "legendFormat": "{{instance}} {{container_label_com_docker_compose_service}}"}
      ]
    }
  ]
}
JSON

cat > "${GRAF_DIR}/dashboards/app-performance.json" <<'JSON'
{
  "uid": "app",
  "title": "Application Performance",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "15s",
  "panels": [
    {
      "type": "timeseries",
      "title": "Request rate (req/s)",
      "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
      "targets": [
        {"expr": "sum(rate(sherlock_http_requests_total[1m])) by (path)", "legendFormat": "{{path}}"}
      ]
    },
    {
      "type": "timeseries",
      "title": "Error rate (5xx req/s)",
      "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
      "targets": [
        {"expr": "sum(rate(sherlock_http_requests_total{status=~\"5..\"}[1m]))", "legendFormat": "5xx"}
      ]
    },
    {
      "type": "timeseries",
      "title": "p95 latency (seconds)",
      "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
      "targets": [
        {"expr": "histogram_quantile(0.95, sum(rate(sherlock_http_request_duration_seconds_bucket[5m])) by (le))", "legendFormat": "p95"}
      ]
    },
    {
      "type": "timeseries",
      "title": "Custom metric: active users estimate",
      "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8},
      "targets": [
        {"expr": "sherlock_custom_active_users", "legendFormat": "active_users"}
      ]
    }
  ]
}
JSON

cat > "${BASE_DIR}/docker-compose.yml" <<'YAML'
services:
  prometheus:
    image: prom/prometheus:v2.54.1
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - /opt/observability/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - /opt/observability/prometheus/rules.yml:/etc/prometheus/rules.yml:ro
      - prom_data:/prometheus

  alertmanager:
    image: prom/alertmanager:v0.28.0
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - /opt/observability/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro

  grafana:
    image: grafana/grafana:11.2.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - /opt/observability/grafana/provisioning:/etc/grafana/provisioning:ro
      - /opt/observability/grafana/dashboards:/var/lib/grafana/dashboards:ro

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.14.1
    container_name: elasticsearch
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
      - ES_JAVA_OPTS=-Xms1g -Xmx1g
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data

  kibana:
    image: docker.elastic.co/kibana/kibana:8.14.1
    container_name: kibana
    restart: unless-stopped
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  logstash:
    image: docker.elastic.co/logstash/logstash:8.14.1
    container_name: logstash
    restart: unless-stopped
    environment:
      - xpack.monitoring.enabled=false
    ports:
      - "5044:5044"
    volumes:
      - /opt/observability/logstash/pipeline:/usr/share/logstash/pipeline:ro
    depends_on:
      - elasticsearch

  elasticsearch-exporter:
    image: quay.io/prometheuscommunity/elasticsearch-exporter:v1.7.0
    container_name: elasticsearch-exporter
    restart: unless-stopped
    command:
      - '--es.uri=http://elasticsearch:9200'
    ports:
      - "9114:9114"
    depends_on:
      - elasticsearch

  alert-webhook:
    image: python:3.12-slim
    container_name: alert-webhook
    restart: unless-stopped
    environment:
      - DISCORD_WEBHOOK=${DISCORD_WEBHOOK:-}
    ports:
      - "5001:5001"
    command: ["python","-u","/app/webhook.py"]
    volumes:
      - /opt/observability/webhook:/app:ro

volumes:
  prom_data: {}
  grafana_data: {}
  es_data: {}
YAML

mkdir -p /opt/observability/webhook
cat > /opt/observability/webhook/webhook.py <<'PY'
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import Request, urlopen

DISCORD_WEBHOOK = os.environ.get("DISCORD_WEBHOOK", "").strip()

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("content-length", "0"))
        body = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(body.decode("utf-8"))
        except Exception:
            payload = {"raw": body.decode("utf-8", errors="replace")}

        print("ALERT RECEIVED:", json.dumps(payload)[:2000])

        if DISCORD_WEBHOOK:
            text = "\n".join(
                [
                    "🚨 Alertmanager notification",
                    json.dumps(payload)[:1700],
                ]
            )
            try:
                req = Request(
                    DISCORD_WEBHOOK,
                    data=json.dumps({"content": text}).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                urlopen(req, timeout=5).read()
            except Exception as e:
                print("Failed to forward to Discord:", str(e))

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, fmt, *args):
        return

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 5001), Handler)
    print("Alert webhook listening on :5001")
    server.serve_forever()
PY

chmod 755 /opt/observability /opt/observability/prometheus /opt/observability/alertmanager
chmod 644 /opt/observability/prometheus/prometheus.yml /opt/observability/prometheus/rules.yml
chmod 644 /opt/observability/alertmanager/alertmanager.yml

docker compose -f "${BASE_DIR}/docker-compose.yml" up -d

echo ">>> [${VM_NAME}] Prometheus:  http://192.168.56.16:9090"
echo ">>> [${VM_NAME}] Grafana:     http://192.168.56.16:3000 (admin/admin)"
echo ">>> [${VM_NAME}] Kibana:      http://192.168.56.16:5601"
echo ">>> [${VM_NAME}] Elasticsearch http://192.168.56.16:9200"
echo ">>> [${VM_NAME}] Monitoring+Logging provisioning complete."