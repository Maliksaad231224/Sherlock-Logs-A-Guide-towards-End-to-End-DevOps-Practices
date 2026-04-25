set -e

VM_NAME="$1"
DEVOPS_USER="devops"

PUBKEY_FILE="/vagrant/devops_authorized_keys"
BACKUP_PUBKEY_FILE="/vagrant/backup_devops_authorized_keys"
CICD_PUBKEY_FILE="/vagrant/cicd_deploy.pub"

echo ">>> [${VM_NAME}] Base provisioning starting..."

export DEBIAN_FRONTEND=noninteractive

if ! id -u "$DEVOPS_USER" >/dev/null 2>&1; then
  echo ">>> Creating user $DEVOPS_USER"
  adduser --disabled-password --gecos "" "$DEVOPS_USER"

  echo "$DEVOPS_USER:1234" | chpasswd
fi

usermod -aG sudo "$DEVOPS_USER"

echo "$DEVOPS_USER ALL=(ALL) ALL" >/etc/sudoers.d/90-devops
chmod 440 /etc/sudoers.d/90-devops

echo "$DEVOPS_USER ALL=(ALL) NOPASSWD: /usr/bin/rsync" >/etc/sudoers.d/91-devops-rsync
chmod 440 /etc/sudoers.d/91-devops-rsync

SSH_DIR="/home/$DEVOPS_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

append_key_file() {
  local file="$1"
  local label="$2"

  if [ -f "$file" ]; then
    echo ">>> Installing ${label} authorized key(s) for $DEVOPS_USER from $file"
    cat "$file" >>"$AUTH_KEYS"
  else
    echo ">>> NOTE: $file not found (${label} key not installed yet)"
  fi
}

append_key_file "$PUBKEY_FILE" "primary"
append_key_file "$BACKUP_PUBKEY_FILE" "backup"
append_key_file "$CICD_PUBKEY_FILE" "cicd"

sort -u "$AUTH_KEYS" -o "$AUTH_KEYS"
chown -R "$DEVOPS_USER:$DEVOPS_USER" "$SSH_DIR"

SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -qE '^\s*#?\s*PasswordAuthentication\s+' "$SSHD_CONFIG"; then
  sed -i 's/^\s*#\?\s*PasswordAuthentication\s\+.*/PasswordAuthentication no/' "$SSHD_CONFIG"
else
  echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
fi

if grep -qE '^\s*#?\s*PermitRootLogin\s+' "$SSHD_CONFIG"; then
  sed -i 's/^\s*#\?\s*PermitRootLogin\s\+.*/PermitRootLogin no/' "$SSHD_CONFIG"
else
  echo "PermitRootLogin no" >> "$SSHD_CONFIG"
fi

grep -q "^AllowUsers" "$SSHD_CONFIG" \
  && sed -i "s/^AllowUsers .*/AllowUsers $DEVOPS_USER vagrant/" "$SSHD_CONFIG" \
  || echo "AllowUsers $DEVOPS_USER vagrant" >>"$SSHD_CONFIG"

systemctl restart ssh || systemctl restart sshd || true

apt-get update -y
apt-get install -y \
  ufw \
  unattended-upgrades \
  fail2ban \
  curl \
  gnupg \
  ca-certificates \
  rsync \
  netdata

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 19999/tcp
ufw --force enable

if grep -q "^UMASK" /etc/login.defs; then
  sed -i 's/^UMASK .*/UMASK 027/' /etc/login.defs
else
  echo "UMASK 027" >> /etc/login.defs
fi

cat >/etc/profile.d/secure-umask.sh <<'EOF'
umask 027
EOF
chmod 644 /etc/profile.d/secure-umask.sh

if ! grep -q "pam_umask.so" /etc/pam.d/common-session; then
  echo "session optional pam_umask.so" >> /etc/pam.d/common-session
fi

dpkg-reconfigure -f noninteractive unattended-upgrades || true

cat >/etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 5
findtime = 10m
bantime  = 1h

[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 1h
EOF

systemctl restart fail2ban

echo ">>> Configuring Netdata..."

NETDATA_CONF="/etc/netdata/netdata.conf"

if grep -q "^\[web\]" "$NETDATA_CONF" 2>/dev/null; then
  sed -i '/^\[web\]/,/^\[/{s/^ *bind to *=.*/    bind to = 0.0.0.0/}' "$NETDATA_CONF"
  if ! grep -q "web files owner" "$NETDATA_CONF"; then
    sed -i '/^\[web\]/a \    web files owner = netdata' "$NETDATA_CONF"
  else
    sed -i 's/^ *web files owner *=.*/    web files owner = netdata/' "$NETDATA_CONF"
  fi
  if ! grep -q "web files group" "$NETDATA_CONF"; then
    sed -i '/^\[web\]/a \    web files group = netdata' "$NETDATA_CONF"
  else
    sed -i 's/^ *web files group *=.*/    web files group = netdata/' "$NETDATA_CONF"
  fi
else
  cat >>"$NETDATA_CONF" <<'EOF'
[global]
    run as user = netdata

[web]
    bind to = 0.0.0.0
    web files owner = netdata
    web files group = netdata
    dashboard mode = local
EOF
fi

chown -R netdata:netdata /usr/share/netdata/web
chmod -R 755 /usr/share/netdata/web

systemctl enable netdata
systemctl restart netdata

HOSTS_BLOCK_START="# BEGIN SS101 HOSTS"
HOSTS_BLOCK_END="# END SS101 HOSTS"

if grep -qF "$HOSTS_BLOCK_START" /etc/hosts; then
  sed -i "/$HOSTS_BLOCK_START/,/$HOSTS_BLOCK_END/d" /etc/hosts
fi

cat >> /etc/hosts <<EOF
$HOSTS_BLOCK_START
192.168.56.10   lb1
192.168.56.11   web1
192.168.56.12   web2
192.168.56.13   app1
192.168.56.14   backup1
192.168.56.15   cicd1
192.168.56.16   mon1
$HOSTS_BLOCK_END
EOF

echo ">>> [${VM_NAME}] Base provisioning complete."