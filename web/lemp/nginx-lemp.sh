#!/usr/bin/env bash
# nginx-lemp.sh — One-command LEMP stack: Nginx + PHP-FPM + MariaDB + SSL.
# SSL is handled by ../ssl/ssl-auto.sh when enabled.
# Blog: https://sultanbp.com/blog/one-command-lemp-stack/
# Run as: root

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[lemp]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[X]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Preflight ────────────────────────────────────────────────────────────────
[[ "$EUID" -ne 0 ]] && error "Run as root. Try: sudo bash nginx-lemp.sh"
command -v apt &>/dev/null || error "apt not found. Requires Ubuntu or Debian."

# ── Locate ssl-auto.sh ────────────────────────────────────────────────────────
# Resolve path relative to this script's location, or fall back to a temp download.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_SCRIPT="$SCRIPT_DIR/../ssl/ssl-auto.sh"

# ── Input ────────────────────────────────────────────────────────────────────
section "Configuration"

LATEST_PHP="8.5"

echo ""
read -rp "  Domain name (e.g. example.com)        : " DOMAIN
read -rp "  PHP version [default: $LATEST_PHP]      : " PHP_VERSION
PHP_VERSION="${PHP_VERSION:-$LATEST_PHP}"
read -rp "  MariaDB root password                  : " -s DB_ROOT_PASS
echo ""
read -rp "  Enable SSL with Let's Encrypt? [Y/n]   : " ENABLE_SSL
ENABLE_SSL="${ENABLE_SSL:-Y}"
if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
  read -rp "  Include www.$DOMAIN in SSL cert? [y/N]  : " INCLUDE_WWW
  INCLUDE_WWW="${INCLUDE_WWW:-N}"
  read -rp "  Email for Let's Encrypt notices (optional, Enter to skip): " CERT_EMAIL
fi

echo ""
echo -e "  ${YELLOW}Summary:${NC}"
echo "    Domain      : $DOMAIN"
echo "    PHP version : $PHP_VERSION"
echo "    SSL         : $([[ "$ENABLE_SSL" =~ ^[Yy]$ ]] && echo yes || echo no)"
[[ "$ENABLE_SSL" =~ ^[Yy]$ ]] && echo "    Include www : $([[ "$INCLUDE_WWW" =~ ^[Yy]$ ]] && echo yes || echo no)"
echo ""
read -rp "  Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── System packages ───────────────────────────────────────────────────────────
section "System Packages"

apt update -qq
apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring software-properties-common
success "Base packages ready"

# ── Nginx ─────────────────────────────────────────────────────────────────────
section "Nginx"

if command -v nginx &>/dev/null; then
  warn "Nginx already installed — skipping"
else
  apt install -y nginx
  systemctl enable nginx
  systemctl start nginx
  success "Nginx installed and started"
fi

# ── PHP-FPM ───────────────────────────────────────────────────────────────────
section "PHP $PHP_VERSION"

if php -v 2>/dev/null | grep -q "PHP $PHP_VERSION"; then
  warn "PHP $PHP_VERSION already installed — skipping"
else
  log "Adding ondrej/php PPA..."
  add-apt-repository -y ppa:ondrej/php
  apt update -qq

  apt install -y \
    "php${PHP_VERSION}-fpm" \
    "php${PHP_VERSION}-mysql" \
    "php${PHP_VERSION}-cli" \
    "php${PHP_VERSION}-common" \
    "php${PHP_VERSION}-curl" \
    "php${PHP_VERSION}-mbstring" \
    "php${PHP_VERSION}-xml" \
    "php${PHP_VERSION}-zip" \
    "php${PHP_VERSION}-bcmath" \
    "php${PHP_VERSION}-intl" \
    "php${PHP_VERSION}-gd"

  systemctl enable "php${PHP_VERSION}-fpm"
  systemctl start  "php${PHP_VERSION}-fpm"
  success "PHP $PHP_VERSION installed"
fi

# ── MariaDB ───────────────────────────────────────────────────────────────────
section "MariaDB"

if command -v mysql &>/dev/null; then
  warn "MariaDB already installed — skipping"
else
  apt install -y mariadb-server

  systemctl enable mariadb
  systemctl start mariadb

  mysql -u root << SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

  success "MariaDB installed and secured"
fi

# ── Nginx site config ─────────────────────────────────────────────────────────
section "Nginx Site Config"

WEBROOT="/var/www/$DOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

mkdir -p "$WEBROOT"
chown -R www-data:www-data "$WEBROOT"

cat > "$NGINX_CONF" << NGINX
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN$([[ "${INCLUDE_WWW:-N}" =~ ^[Yy]$ ]] && echo " www.$DOMAIN");
    root $WEBROOT;
    index index.php index.html;

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN"
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
success "Nginx site configured for $DOMAIN"

# ── Webroot setup ─────────────────────────────────────────────────────────────
section "Webroot"

cat > "$WEBROOT/index.html" << HTML
<!DOCTYPE html>
<html><head><title>$DOMAIN</title></head>
<body><h1>$DOMAIN is live.</h1><p>Replace this file with your app.</p></body>
</html>
HTML

chown -R www-data:www-data "$WEBROOT"
chmod -R 755 "$WEBROOT"
success "Webroot ready: $WEBROOT"

# ── SSL ───────────────────────────────────────────────────────────────────────
if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
  section "SSL (Let's Encrypt)"

  if [[ -f "$SSL_SCRIPT" ]]; then
    log "Delegating to ssl-auto.sh..."
    DOMAIN="$DOMAIN" \
    INCLUDE_WWW="${INCLUDE_WWW:-N}" \
    CERT_EMAIL="${CERT_EMAIL:-}" \
    WEBSERVER="nginx" \
      bash "$SSL_SCRIPT"
  else
    # Fallback: download ssl-auto.sh if not found locally (e.g. curl-pipe-bash usage)
    log "ssl-auto.sh not found locally — downloading..."
    SSL_TMP=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/web/ssl/ssl-auto.sh -o "$SSL_TMP"
    DOMAIN="$DOMAIN" \
    INCLUDE_WWW="${INCLUDE_WWW:-N}" \
    CERT_EMAIL="${CERT_EMAIL:-}" \
    WEBSERVER="nginx" \
      bash "$SSL_TMP"
    rm -f "$SSL_TMP"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  LEMP stack ready.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Domain   : $DOMAIN"
echo "  Webroot  : $WEBROOT"
echo "  PHP      : $PHP_VERSION (FPM)"
echo "  Database : MariaDB"
echo "  SSL      : $([[ "$ENABLE_SSL" =~ ^[Yy]$ ]] && echo "Let's Encrypt (auto-renewal)" || echo "disabled")"
echo ""
echo "  Verify:"
echo "  - Site : http$([[ "$ENABLE_SSL" =~ ^[Yy]$ ]] && echo s)://$DOMAIN"
echo ""
echo "  Next:"
echo "  1. Deploy your app to: $WEBROOT"
echo ""
echo "  Blog: https://sultanbp.com/blog/one-command-lemp-stack/"
echo ""
