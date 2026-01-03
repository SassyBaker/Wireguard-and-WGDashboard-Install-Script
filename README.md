# 🛡️ WireGuard & WGDashboard Install Script

![GitHub last commit](https://img.shields.io/github/last-commit/SassyBaker/Wireguard-and-WGDashboard-Install-Script)
![GitHub issues](https://img.shields.io/github/issues/SassyBaker/Wireguard-and-WGDashboard-Install-Script)
![License](https://img.shields.io/github/license/SassyBaker/Wireguard-and-WGDashboard-Install-Script)

Automated installer for **WireGuard** VPN + **WGDashboard** on Debian servers.  
This script configures WireGuard, installs WGDashboard, optionally sets up **Nginx + HTTPS**, and configures a firewall for secure access.

---

## 🧠 What This Script Does

✔ Installs **WireGuard** with automatic server keys  
✔ Sets up **WGDashboard** using its own install utility (`wgd.sh`) :contentReference[oaicite:1]{index=1}  
✔ Configures **UFW firewall**  
✔ Optionally sets up **Nginx reverse proxy** with **Let’s Encrypt HTTPS**  
✔ Enables IPv4 forwarding  

---

## 🚀 Features

| Feature | Works Out of the Box |
|---------|----------------------|
| WireGuard VPN | ✅ |
| WGDashboard UI | ✅ |
| Nginx Reverse Proxy | Optional |
| HTTPS (Let’s Encrypt) | Optional |
| Firewall (UFW) | ✅ |
| Automatic Key Generation | ✅ |

---

## 📦 Requirements

Make sure you are running Debian 11 or Debian 12 with **root** privileges.

The script will install:

- `wireguard`, `wireguard-tools`  
- `git`, `python3`, `python3-venv`, `python3-pip`  
- `iptables`  
- `ufw`  
- `nginx`, `certbot`, `python3-certbot-nginx`  

You’ll be prompted for:
- Domain name for the dashboard (if you want HTTPS)
- Let's Encrypt email address
- WireGuard interface settings

---

## 📦 One‑Line Installation

Run **everything** with one command:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SassyBaker/Wireguard-and-WGDashboard-Install-Script/main/install-wg.sh)"
