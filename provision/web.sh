set -e

VM_NAME="$1"

echo ">>> [${VM_NAME}] Web provisioning..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y nginx

systemctl enable nginx

cat >/etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location /app/ {
        proxy_pass http://192.168.56.13:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

echo "This is ${VM_NAME}" >/var/www/html/index.html

nginx -t
systemctl restart nginx

echo ">>> [${VM_NAME}] Web provisioning complete."