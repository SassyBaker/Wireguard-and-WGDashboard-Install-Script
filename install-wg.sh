#!/usr/bin/env bash
set -e

### ===== Root check =====
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "=== WGDashboard + WireGuard Installer (Debian 11/12) ==="

### ===== PROMPTS =====
read -rp "Domain name for Nginx (optional, leave empty to skip HTTPS): " DOMAIN
read -rp "Email for Let's Encrypt notifications (required if domain is set): " EMAIL

read -rp "WireGuard interface name [wg0]: " WG_INTERFACE
WG_INTERFACE=${WG_INTERFACE:-wg0}

read -rp "WireGuard UDP port [51820]: " WG_PORT
WG_PORT=${WG_PORT:-51820}

read -rp "WireGuard subnet CIDR [10.10.0.1/24]: " WG_SUBNET
WG_SUBNET=${WG_SUBNET:-10.10.0.1/24}

DASHBOARD_PORT=10086
DASHBOARD_DIR="/opt/WGDashboard"

echo
echo "=== Configuration Summary ==="
echo "Domain:              ${DOMAIN:-None}"
echo "Email:               ${EMAIL:-None}"
echo "WG Interface:        $WG_INTERFACE"
echo "WG Port:             $WG_PORT/udp"
echo "WG Subnet:           $WG_SUBNET"
echo "Dashboard Port:      $DASHBOARD_PORT"
echo

read -rp "Continue installation? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

### ===== Update system & install dependencies =====
echo "=== Installing dependencies ==="
apt update && apt upgrade -y
apt install -y python3 python3-venv python3-pip git wireguard wireguard-tools net-tools iptables ufw nginx certbot python3-certbot-nginx ca-certificates

### ===== WireGuard Setup =====
echo "=== Enabling IPv4 forwarding ==="
echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-wireguard.conf
sysctl --system

mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

if [ ! -f /etc/wireguard/privatekey ]; then
  echo "=== Generating WireGuard keys ==="
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
  chmod 600 /etc/wireguard/privatekey
fi

PRIVATE_KEY=$(cat /etc/wireguard/privatekey)

echo "=== Creating WireGuard config ==="
cat > /etc/wireguard/${WG_INTERFACE}.conf <<EOF
[Interface]
Address = ${WG_SUBNET}
ListenPort = ${WG_PORT}
PrivateKey = ${PRIVATE_KEY}
SaveConfig = true

PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -A FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o \$(ip route get 1 | awk '{print \$5; exit}') -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -D FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o \$(ip route get 1 | awk '{print \$5; exit}') -j MASQUERADE
EOF

chmod 600 /etc/wireguard/${WG_INTERFACE}.conf
systemctl enable wg-quick@${WG_INTERFACE}
systemctl start wg-quick@${WG_INTERFACE}

### ===== WGDashboard Installation =====
echo "=== Installing WGDashboard ==="
cd /opt
if [ ! -d WGDashboard ]; then
  git clone https://github.com/WGDashboard/WGDashboard.git
fi

cd ${DASHBOARD_DIR}/src
chmod u+x wgd.sh
sudo ./wgd.sh install

# Fix permissions and create backup folder
chmod -R 755 /etc/wireguard
mkdir -p ${DASHBOARD_DIR}/WGDashboard_Backup
chmod 700 ${DASHBOARD_DIR}/WGDashboard_Backup

sudo ./wgd.sh start

echo
echo "WGDashboard is running on port $DASHBOARD_PORT"
echo "Access it via http://<server_ip>:$DASHBOARD_PORT"
echo "Default login: admin / admin"

### ===== Optional: Setup Nginx + HTTPS =====
if [[ -n "$DOMAIN" && -n "$EMAIL" ]]; then
  echo "=== Configuring Nginx reverse proxy ==="
  cat > /etc/nginx/sites-available/WGDashboard <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:${DASHBOARD_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/WGDashboard /etc/nginx/sites-enabled/WGDashboard
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx

  echo "=== Requesting HTTPS certificate ==="
  certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
fi

### ===== Optional: Enable firewall =====
echo "=== Configuring UFW firewall ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow ${WG_PORT}/udp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo
echo "=== INSTALLATION COMPLETE ==="
if [[ -n "$DOMAIN" ]]; then
  echo "Dashboard URL: https://${DOMAIN}"
else
  echo "Dashboard URL: http://<server_ip>:${DASHBOARD_PORT}"
fi
echo "WireGuard Port: ${WG_PORT}/udp"
