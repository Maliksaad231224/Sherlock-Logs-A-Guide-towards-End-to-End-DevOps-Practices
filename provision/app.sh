set -e

VM_NAME="$1"
DEVOPS_USER="devops"

echo ">>> [${VM_NAME}] App server provisioning..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y python3 python3-venv curl

APP_DIR="/home/${DEVOPS_USER}/app"
mkdir -p "${APP_DIR}"

cat >"${APP_DIR}/app.py" <<'EOF'
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/health"):
            message = "OK"
        else:
            message = "Hello from APP1"

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(message.encode())

    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), Handler)
    print("App running on port 8080...")
    server.serve_forever()
EOF

chown -R ${DEVOPS_USER}:${DEVOPS_USER} "${APP_DIR}"

cat >/etc/systemd/system/app1.service <<EOF
[Unit]
Description=Simple HTTP application on APP1
After=network.target

[Service]
User=${DEVOPS_USER}
Group=${DEVOPS_USER}
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/python3 ${APP_DIR}/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat >/usr/local/bin/app1-health-check.sh <<'EOF'
#!/usr/bin/env bash
set -e
URL="http://127.0.0.1:8080/health"

if ! curl -fsS --max-time 3 "$URL" > /dev/null; then
  echo "[$(date)] Health check FAILED, restarting app1.service" >> /var/log/app1-health.log
  systemctl restart app1.service
else
  echo "[$(date)] Health check OK" >> /var/log/app1-health.log
fi
EOF

chmod +x /usr/local/bin/app1-health-check.sh

cat >/etc/systemd/system/app1-health.service <<'EOF'
[Unit]
Description=Health check for APP1 HTTP service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/app1-health-check.sh
EOF

cat >/etc/systemd/system/app1-health.timer <<'EOF'
[Unit]
Description=Run APP1 health check every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=app1-health.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable app1.service
systemctl start app1.service

systemctl enable --now app1-health.timer

ufw allow from 192.168.56.0/24 to any port 8080 proto tcp

echo ">>> [${VM_NAME}] App server provisioning complete."