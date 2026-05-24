#!/usr/bin/env bash
# =============================================================================
# setup-vps.sh
# Full VPS initial setup and hardening for Ubuntu/Debian.
# Companion doc: https://sultanbp.com/docs/linux/vps-setup-hardening
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/vps/setup-vps.sh | bash
#
# What this script does:
#   1. Prompts for username, hostname, and timezone
#   2. Creates a non-root sudo user
#   3. Copies your SSH public key to the new user
#   4. Hardens SSH (disables root login + password auth)
#   5. Configures UFW firewall (SSH + HTTP + HTTPS)
#   6. Installs and configures Fail2ban
#   7. Enables unattended security updates
#   8. Updates system packages and installs common utilities
#   9. Sets hostname and timezone
#  10. Installs Docker
#  11. Writes a custom MOTD
#
# Run as: root (or with sudo)
# =============================================================================

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

# ── Root check ───────────────────────────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
  error "This script must be run as root. Try: sudo bash setup-vps.sh"
fi

# ── OS check ─────────────────────────────────────────────────────────────────
if ! command -v apt &>/dev/null; then
  error "apt not found. This script requires Ubuntu or Debian."
fi

# ── Input variables ──────────────────────────────────────────────────────────
section "Configuration"

echo ""
read -rp "  New sudo username       : " NEW_USER
read -rp "  Server hostname         : " SERVER_HOSTNAME
read -rp "  Timezone (e.g. Asia/Jakarta) : " SERVER_TIMEZONE

echo ""
echo -e "  ${YELLOW}Summary:${NC}"
echo "    User     : $NEW_USER"
echo "    Hostname : $SERVER_HOSTNAME"
echo "    Timezone : $SERVER_TIMEZONE"
echo ""
read -rp "  Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Step 1: Create non-root user ─────────────────────────────────────────────
section "User Setup"

if id "$NEW_USER" &>/dev/null; then
  warn "User '$NEW_USER' already exists — skipping creation"
else
  log "Creating user: $NEW_USER"
  adduser --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  success "User '$NEW_USER' created and added to sudo group"
fi

# ── Step 2: Copy SSH key ──────────────────────────────────────────────────────
section "SSH Key Setup"

ROOT_AUTHORIZED="$HOME/.ssh/authorized_keys"
USER_SSH_DIR="/home/$NEW_USER/.ssh"
USER_AUTHORIZED="$USER_SSH_DIR/authorized_keys"

if [[ -f "$ROOT_AUTHORIZED" ]]; then
  log "Copying SSH authorized_keys from root to $NEW_USER..."
  mkdir -p "$USER_SSH_DIR"
  cp "$ROOT_AUTHORIZED" "$USER_AUTHORIZED"
  chown -R "$NEW_USER:$NEW_USER" "$USER_SSH_DIR"
  chmod 700 "$USER_SSH_DIR"
  chmod 600 "$USER_AUTHORIZED"
  success "SSH key copied to /home/$NEW_USER/.ssh/authorized_keys"
else
  warn "No authorized_keys found at $ROOT_AUTHORIZED"
  warn "You will need to manually copy your SSH public key:"
  warn "  ssh-copy-id $NEW_USER@<server-ip>"
fi

# ── Step 3: Harden SSH ────────────────────────────────────────────────────────
section "SSH Hardening"

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"

log "Backing up sshd_config to $SSHD_BACKUP"
cp "$SSHD_CONFIG" "$SSHD_BACKUP"

log "Applying SSH hardening settings..."

# Disable root login
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
grep -q "^PermitRootLogin" "$SSHD_CONFIG" || echo "PermitRootLogin no" >> "$SSHD_CONFIG"

# Disable password auth
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication no" >> "$SSHD_CONFIG"

# Enable pubkey auth
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
grep -q "^PubkeyAuthentication" "$SSHD_CONFIG" || echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"

systemctl restart ssh
success "SSH hardened — root login and password auth disabled"

warn "IMPORTANT: Test SSH access as '$NEW_USER' in a new terminal before closing this session."

# ── Step 4: UFW Firewall ──────────────────────────────────────────────────────
section "Firewall (UFW)"

apt install -y ufw -qq

log "Configuring UFW rules..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

success "UFW enabled — allowed: SSH, HTTP (80), HTTPS (443)"
ufw status

# ── Step 5: Fail2ban ──────────────────────────────────────────────────────────
section "Fail2ban"

apt install -y fail2ban -qq

# Write jail.local
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
success "Fail2ban installed and configured (bantime: 1h, maxretry: 5)"

# ── Step 6: Unattended upgrades ───────────────────────────────────────────────
section "Automatic Security Updates"

apt install -y unattended-upgrades -qq

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

success "Unattended security updates enabled"

# ── Step 7: System packages ───────────────────────────────────────────────────
section "System Packages"

log "Updating system packages..."
apt update -qq && apt upgrade -y -qq

log "Installing common utilities..."
apt install -y \
  curl \
  wget \
  git \
  vim \
  unzip \
  htop \
  net-tools \
  ca-certificates \
  gnupg \
  lsb-release

success "System packages updated and utilities installed"

# ── Step 8: Hostname and timezone ─────────────────────────────────────────────
section "Hostname and Timezone"

log "Setting hostname to: $SERVER_HOSTNAME"
hostnamectl set-hostname "$SERVER_HOSTNAME"

# Update /etc/hosts
if grep -q "127.0.1.1" /etc/hosts; then
  sed -i "s/^127.0.1.1.*/127.0.1.1   $SERVER_HOSTNAME/" /etc/hosts
else
  echo "127.0.1.1   $SERVER_HOSTNAME" >> /etc/hosts
fi

log "Setting timezone to: $SERVER_TIMEZONE"
timedatectl set-timezone "$SERVER_TIMEZONE"

success "Hostname: $SERVER_HOSTNAME | Timezone: $SERVER_TIMEZONE"

# ── Step 9: Docker ────────────────────────────────────────────────────────────
section "Docker"

if command -v docker &>/dev/null; then
  warn "Docker already installed — skipping"
else
  log "Installing Docker via official install script..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  rm /tmp/get-docker.sh
  success "Docker installed"
fi

log "Adding $NEW_USER to docker group..."
usermod -aG docker "$NEW_USER"
success "$NEW_USER added to docker group"

# ── Step 10: Custom MOTD ──────────────────────────────────────────────────────
section "Custom MOTD"

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
echo "  Summary:"
echo "    User     : $NEW_USER (sudo)"
echo "    Hostname : $SERVER_HOSTNAME"
echo "    Timezone : $SERVER_TIMEZONE"
echo "    Firewall : UFW active (SSH, 80, 443)"
echo "    Fail2ban : active"
echo "    Docker   : installed"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Open a NEW terminal and verify SSH access:"
echo "     ssh $NEW_USER@<server-ip>"
echo ""
echo "  2. Only after confirming access — close this root session."
echo ""
echo "  3. Optional: set up zsh for $NEW_USER"
echo "     curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/zsh/setup-zsh.sh | bash"
echo ""
echo "  Full docs: https://sultanbp.com/docs/linux/vps-setup-hardening"
echo ""
