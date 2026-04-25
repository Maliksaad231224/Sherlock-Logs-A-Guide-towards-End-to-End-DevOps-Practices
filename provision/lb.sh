set -e

VM_NAME="$1"
echo ">>> [${VM_NAME}] Load balancer + VPN provisioning..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y nginx

systemctl enable nginx
systemctl restart nginx

rm -f /etc/nginx/sites-enabled/default || true

cat >/etc/nginx/sites-available/loadbalancer.conf <<'EOF'
upstream web_backend {
    server 192.168.56.11 max_fails=3 fail_timeout=10s;
    server 192.168.56.12 max_fails=3 fail_timeout=10s;
}

server {
    listen 80;

    location / {
        proxy_pass http://web_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /app/ {
        proxy_pass http://web_backend/app/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/loadbalancer.conf /etc/nginx/sites-enabled/loadbalancer.conf

nginx -t
systemctl restart nginx

apt-get install -y wireguard

mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077

if [ ! -f server.key ]; then
  echo ">>> Generating WireGuard server keys"
  wg genkey | tee server.key | wg pubkey > server.pub
fi

if [ ! -f client-charles.key ]; then
  echo ">>> Generating WireGuard client keys for Charles"
  wg genkey | tee client-charles.key | wg pubkey > client-charles.pub
fi

SERVER_PRIV_KEY=$(cat server.key)
SERVER_PUB_KEY=$(cat server.pub)
CLIENT_PRIV_KEY=$(cat client-charles.key)
CLIENT_PUB_KEY=$(cat client-charles.pub)

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address    = 10.10.0.1/24
ListenPort = 51820
PrivateKey = ${SERVER_PRIV_KEY}
SaveConfig = false

[Peer]
# Charles laptop
PublicKey  = ${CLIENT_PUB_KEY}
AllowedIPs = 10.10.0.2/32
EOF

if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p

if ! grep -q "10.10.0.0/24 -o enp0s8 -j MASQUERADE" /etc/ufw/before.rules; then
  sed -i '1s/^/*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 10.10.0.0\/24 -o enp0s8 -j MASQUERADE\nCOMMIT\n\n&/' /etc/ufw/before.rules
fi

ufw allow 51820/udp

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

TMP_CONF="/tmp/wg-charles.conf"

cat > "$TMP_CONF" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address    = 10.10.0.2/32
DNS        = 1.1.1.1

[Peer]
PublicKey  = ${SERVER_PUB_KEY}
Endpoint   = 192.168.56.10:51820
AllowedIPs = 10.10.0.0/24, 192.168.56.0/24
PersistentKeepalive = 25
EOF

[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address    = 10.10.0.2/32
DNS        = 1.1.1.1

[Peer]
PublicKey  = ${SERVER_PUB_KEY}
Endpoint   = 192.168.56.10:51820
AllowedIPs = 10.10.0.0/24, 192.168.56.0/24
PersistentKeepalive = 25
EOF

echo ">>> [${VM_NAME}] Load balancer + VPN provisioning complete."
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# 👇 NEW BLOCK HERE (Step 1 + Step 2)

echo ">>> [${VM_NAME}] Load balancer + VPN provisioning complete."