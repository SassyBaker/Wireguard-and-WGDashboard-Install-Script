#!/usr/bin/env bash
set -e

### ===== Root check =====
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "=== WireGuard + WGDashboard Installer (Debian 11/12) ==="

### ===== PROMPTS =====
read -rp "Domain name for Nginx & Peer Endpoint (optional): " DOMAIN
read -rp "Email for Let's Encrypt notifications (required if domain is set): " EMAIL

read -rp "WireGuard interface name [wg0]: " WG_INTERFACE
WG_INTERFACE=${WG_INTERFACE:-wg0}

read -rp "WireGuard UDP port [51820]: " WG_PORT
WG_PORT=${WG_PORT:-51820}

read -rp "WireGuard server IP/CIDR [10.10.0.1/24]: " WG_ADDRESS
WG_ADDRESS=${WG_ADDRESS:-10.10.0.1/24}

DASHBOARD_PORT=10086
DASHBOARD_DIR="/opt/WGDashboard"

echo
echo "=== Configuration Summary ==="
echo "Domain:              ${DOMAIN:-None}"
echo "Email:               ${EMAIL:-None}"
echo "WG Interface:        $WG_INTERFACE"
echo "WG Port:             $WG_PORT/udp"
echo "WG Address:          $WG_ADDRESS"
echo "Dashboard Port:      $DASHBOARD_PORT"
echo

read -rp "Continue installation? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

### ===== System update & dependencies =====
echo "=== Installing dependencies ==="
apt update && apt upgrade -y
apt install -y \
  python3 python3-venv python3-pip git \
  wireguard wireguard-tools \
  iptables iptables-persistent acl \
  net-tools ufw nginx \
  certbot python3-certbot-nginx ca-certificates

### ===== Enable IPv4 forwarding =====
echo "=== Enabling IPv4 forwarding ==="
cat > /etc/sysctl.d/99-wireguard.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl --system

### ===== WireGuard setup =====
echo "=== Configuring WireGuard ==="
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

if [ ! -f /etc/wireguard/privatekey ]; then
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
  chmod 600 /etc/wireguard/privatekey
fi

PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
EXT_IF=$(ip route get 1 | awk '{print $5; exit}')

cat > /etc/wireguard/${WG_INTERFACE}.conf <<EOF
[Interface]
Address = ${WG_ADDRESS}
ListenPort = ${WG_PORT}
PrivateKey = ${PRIVATE_KEY}
SaveConfig = true

PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -A FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${EXT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -D FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${EXT_IF} -j MASQUERADE
EOF

chmod 600 /etc/wireguard/${WG_INTERFACE}.conf
systemctl enable wg-quick@${WG_INTERFACE}
systemctl restart wg-quick@${WG_INTERFACE}
netfilter-persistent save

### ===== WGDashboard installation =====
echo "=== Installing WGDashboard ==="
cd /opt
if [ ! -d WGDashboard ]; then
  git clone https://github.com/WGDashboard/WGDashboard.git
fi

cd ${DASHBOARD_DIR}/src
chmod +x wgd.sh
./wgd.sh install

### ===== WGDashboard systemd service =====
echo "=== Configuring WGDashboard systemd service ==="

if ! id wgdashboard &>/dev/null; then
  useradd -r -d ${DASHBOARD_DIR} -s /usr/sbin/nologin wgdashboard
fi

chown -R wgdashboard:wgdashboard ${DASHBOARD_DIR}

setfacl -R -m u:wgdashboard:rwX /etc/wireguard
setfacl -R -m d:u:wgdashboard:rwX /etc/wireguard

./wgd.sh stop || true

cat > /etc/systemd/system/wgdashboard.service <<EOF
[Unit]
Description=WGDashboard - WireGuard Dashboard
After=network.target wg-quick@${WG_INTERFACE}.service
Wants=wg-quick@${WG_INTERFACE}.service

[Service]
User=wgdashboard
Group=wgdashboard
WorkingDirectory=${DASHBOARD_DIR}/src
ExecStart=/usr/bin/python3 dashboard.py
Restart=always
RestartSec=5
Environment=WG_DASHBOARD_ROOT=${DASHBOARD_DIR}
Environment=PYTHONUNBUFFERED=1
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/etc/wireguard ${DASHBOARD_DIR}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable wgdashboard
systemctl restart wgdashboard

### ===== Set default Peer Remote Endpoint =====
if [[ -n "$DOMAIN" ]]; then
  echo "=== Setting WGDashboard peer endpoint to ${DOMAIN}:${WG_PORT} ==="

  CONFIG_FILE="${DASHBOARD_DIR}/src/config.ini"
  touch "$CONFIG_FILE"
  chown wgdashboard:wgdashboard "$CONFIG_FILE"
  chmod 640 "$CONFIG_FILE"

  if grep -q "^peer_endpoint" "$CONFIG_FILE"; then
    sed -i "s|^peer_endpoint.*|peer_endpoint = ${DOMAIN}:${WG_PORT}|" "$CONFIG_FILE"
  else
    echo "peer_endpoint = ${DOMAIN}:${WG_PORT}" >> "$CONFIG_FILE"
  fi

  systemctl restart wgdashboard
fi

### ===== Nginx + HTTPS =====
if [[ -n "$DOMAIN" && -n "$EMAIL" ]]; then
  echo "=== Configuring Nginx ==="
  cat > /etc/nginx/sites-available/WGDashboard <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${DASHBOARD_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/WGDashboard /etc/nginx/sites-enabled/WGDashboard
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx

  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || \
    echo "⚠️ Certbot failed — fix DNS and re-run certbot manually."
fi

### ===== UFW firewall =====
echo "=== Configuring UFW ==="
sed -i 's/^#*DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow ${WG_PORT}/udp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw reload

### ===== DONE =====
echo
echo "=== INSTALLATION COMPLETE ==="
echo "WGDashboard runs as a systemd service"
echo "⚠️ CHANGE DEFAULT LOGIN: admin / admin"

if [[ -n "$DOMAIN" ]]; then
  echo "Dashboard URL: https://${DOMAIN}"
else
  echo "Dashboard URL: http://127.0.0.1:${DASHBOARD_PORT}"
fi

echo "WireGuard Endpoint for peers: ${DOMAIN:-<server-ip>}:${WG_PORT}"
