#!/usr/bin/env bash
# setup-vps.sh — Full VPS setup and hardening for Ubuntu/Debian.
# Docs: https://sultanbp.com/docs/linux/vps-setup-hardening
# Run as: root

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[vps-setup]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Preflight ────────────────────────────────────────────────────────────────
[[ "$EUID" -ne 0 ]] && error "Run as root. Try: sudo bash setup-vps.sh"
command -v apt &>/dev/null || error "apt not found. Requires Ubuntu or Debian."

# ── Input ────────────────────────────────────────────────────────────────────
section "Configuration"

echo ""
read -rp "  New sudo username            : " NEW_USER
read -rp "  Server hostname              : " SERVER_HOSTNAME
read -rp "  Timezone (e.g. Asia/Jakarta) : " SERVER_TIMEZONE

echo ""
echo -e "  ${YELLOW}Summary:${NC}"
echo "    User     : $NEW_USER"
echo "    Hostname : $SERVER_HOSTNAME"
echo "    Timezone : $SERVER_TIMEZONE"
echo ""
read -rp "  Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── User ─────────────────────────────────────────────────────────────────────
section "User Setup"

if id "$NEW_USER" &>/dev/null; then
  warn "User '$NEW_USER' already exists — skipping"
else
  adduser --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  success "User '$NEW_USER' created and added to sudo"
fi

# ── SSH key ──────────────────────────────────────────────────────────────────
section "SSH Key"

ROOT_AUTHORIZED="$HOME/.ssh/authorized_keys"
USER_SSH_DIR="/home/$NEW_USER/.ssh"
USER_AUTHORIZED="$USER_SSH_DIR/authorized_keys"

if [[ -f "$ROOT_AUTHORIZED" ]]; then
  mkdir -p "$USER_SSH_DIR"
  cp "$ROOT_AUTHORIZED" "$USER_AUTHORIZED"
  chown -R "$NEW_USER:$NEW_USER" "$USER_SSH_DIR"
  chmod 700 "$USER_SSH_DIR"
  chmod 600 "$USER_AUTHORIZED"
  success "SSH key copied to $USER_AUTHORIZED"
else
  warn "No authorized_keys found at $ROOT_AUTHORIZED"
  warn "Copy your key manually: ssh-copy-id $NEW_USER@<server-ip>"
fi

# ── SSH hardening ─────────────────────────────────────────────────────────────
section "SSH Hardening"

SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/'         "$SSHD_CONFIG"
grep -q "^PermitRootLogin"      "$SSHD_CONFIG" || echo "PermitRootLogin no"      >> "$SSHD_CONFIG"

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication no" >> "$SSHD_CONFIG"

sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
grep -q "^PubkeyAuthentication" "$SSHD_CONFIG" || echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"

systemctl restart ssh
success "SSH hardened — root login and password auth disabled"
warn "Test SSH access as '$NEW_USER' in a new terminal before closing this session."

# ── Firewall ──────────────────────────────────────────────────────────────────
section "Firewall (UFW)"

apt install -y ufw -qq
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
success "UFW enabled — SSH, HTTP (80), HTTPS (443)"
ufw status

# ── Fail2ban ──────────────────────────────────────────────────────────────────
section "Fail2ban"

apt install -y fail2ban -qq

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban
success "Fail2ban configured (bantime: 1h, maxretry: 5)"

# ── Automatic updates ─────────────────────────────────────────────────────────
section "Automatic Security Updates"

apt install -y unattended-upgrades -qq

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

success "Unattended security updates enabled"

# ── System packages ───────────────────────────────────────────────────────────
section "System Packages"

apt update -qq && apt upgrade -y -qq
apt install -y curl wget git vim unzip htop net-tools ca-certificates gnupg lsb-release
success "System packages updated"

# ── Hostname and timezone ─────────────────────────────────────────────────────
section "Hostname and Timezone"

hostnamectl set-hostname "$SERVER_HOSTNAME"

if grep -q "127.0.1.1" /etc/hosts; then
  sed -i "s/^127.0.1.1.*/127.0.1.1   $SERVER_HOSTNAME/" /etc/hosts
else
  echo "127.0.1.1   $SERVER_HOSTNAME" >> /etc/hosts
fi

timedatectl set-timezone "$SERVER_TIMEZONE"
success "Hostname: $SERVER_HOSTNAME | Timezone: $SERVER_TIMEZONE"

# ── Docker ────────────────────────────────────────────────────────────────────
section "Docker"

if command -v docker &>/dev/null; then
  warn "Docker already installed — skipping"
else
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  rm /tmp/get-docker.sh
  success "Docker installed"
fi

usermod -aG docker "$NEW_USER"
success "$NEW_USER added to docker group"

# ── MOTD ──────────────────────────────────────────────────────────────────────
section "MOTD"

cat > /etc/update-motd.d/99-custom << 'MOTD_EOF'
#!/bin/bash
echo ""
echo "======================================="
echo "   $(hostname) — Cloud Lab"
echo "======================================="
echo ""
echo " Uptime  : $(uptime -p)"
echo " Memory  : $(free -h | awk '/Mem:/ { print $3 "/" $2 }')"
echo " Disk    : $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
echo " Load    : $(cut -d' ' -f1-3 /proc/loadavg)"
echo ""
MOTD_EOF

chmod +x /etc/update-motd.d/99-custom
success "Custom MOTD written"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  VPS setup complete.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  User     : $NEW_USER (sudo)"
echo "  Hostname : $SERVER_HOSTNAME"
echo "  Timezone : $SERVER_TIMEZONE"
echo "  Firewall : UFW active (SSH, 80, 443)"
echo "  Fail2ban : active"
echo "  Docker   : installed"
echo ""
echo "  Next:"
echo "  1. Verify SSH in a new terminal: ssh $NEW_USER@<server-ip>"
echo "  2. Only then close this root session."
echo ""
echo "  Docs: https://sultanbp.com/docs/linux/vps-setup-hardening"
echo ""
