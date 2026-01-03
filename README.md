# 🛡️ WireGuard + WGDashboard Installer


Automated installer for **WireGuard VPN** with **WGDashboard** on **Debian 11/12**.  
Sets up WireGuard, WGDashboard, Nginx with HTTPS, and firewall automatically.

---

## 🏷️ Badges

![GitHub last commit](https://img.shields.io/github/last-commit/YOUR_USERNAME/YOUR_REPO)
![GitHub issues](https://img.shields.io/github/issues/YOUR_USERNAME/YOUR_REPO)
![License](https://img.shields.io/github/license/YOUR_USERNAME/YOUR_REPO)

---

## 📑 Table of Contents

1. [Features](#-features)  
2. [Requirements](#-requirements)  
3. [One-line Installation](#-one-line-install)  
4. [Manual Installation](#-manual-installation-optional)  
5. [Security Recommendations](#-security-recommendations)  
6. [Troubleshooting](#-troubleshooting)  
7. [License](#-license)  

---

## ⚡ Features

- Installs **WireGuard** and generates server keys automatically  
- Installs **WGDashboard** in a Python virtual environment  
- Configures **Nginx reverse proxy** with HTTPS via Let’s Encrypt  
- Sets up **UFW firewall** with secure defaults  
- Fully automated: minimal user input required  
- Optional: custom ports, interface names, and subnets  

---

## 📦 Requirements

- Debian 11 or Debian 12  
- Root user (`sudo`)  
- Domain name (for HTTPS / WGDashboard)  
- Email address (for Let’s Encrypt notifications)  

---

## 🚀 One-line Installation

Run the installer directly from GitHub:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install-wg.sh)"


sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SassyBaker/Wireguard-and-WGDashboard-Install-Script/main/install-wg.sh)"
