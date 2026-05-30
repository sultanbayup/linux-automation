#!/usr/bin/env bash
# ssl-auto.sh — Standalone SSL certificate automation via Let's Encrypt.
# Works with any running Nginx or Apache on Ubuntu/Debian.
# Can be called directly or sourced by other scripts (e.g. nginx-lemp.sh).
# Run as: root

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[ssl-auto]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Preflight ────────────────────────────────────────────────────────────────
[[ "$EUID" -ne 0 ]] && error "Run as root. Try: sudo bash ssl-auto.sh"
command -v apt &>/dev/null || error "apt not found. Requires Ubuntu or Debian."

# ── Detect web server ─────────────────────────────────────────────────────────
detect_webserver() {
  if systemctl is-active --quiet nginx 2>/dev/null; then
    echo "nginx"
  elif systemctl is-active --quiet apache2 2>/dev/null; then
    echo "apache"
  else
    echo "none"
  fi
}

# ── Input ────────────────────────────────────────────────────────────────────
# Accept env vars for non-interactive use (e.g. called from nginx-lemp.sh),
# or prompt interactively when run standalone.

_interactive=false
[[ -z "${DOMAIN:-}" ]] && _interactive=true

if [[ "$_interactive" == "true" ]]; then
  section "SSL Configuration"

  WEBSERVER=$(detect_webserver)
  if [[ "$WEBSERVER" == "none" ]]; then
    error "No running web server detected. Start Nginx or Apache before running this script."
  fi
  log "Detected web server: $WEBSERVER"

  echo ""
  read -rp "  Domain name (e.g. example.com)        : " DOMAIN
  read -rp "  Include www.$DOMAIN in cert? [y/N]     : " INCLUDE_WWW
  INCLUDE_WWW="${INCLUDE_WWW:-N}"
  read -rp "  Email for Let's Encrypt notices        : " CERT_EMAIL

  echo ""
  echo -e "  ${YELLOW}Summary:${NC}"
  echo "    Domain      : $DOMAIN"
  echo "    Include www : $([[ "$INCLUDE_WWW" =~ ^[Yy]$ ]] && echo yes || echo no)"
  echo "    Email       : ${CERT_EMAIL:-none (--register-unsafely-without-email)}"
  echo "    Web server  : $WEBSERVER"
  echo ""
  read -rp "  Proceed? [y/N] " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
else
  # Called from another script — use provided env vars
  INCLUDE_WWW="${INCLUDE_WWW:-N}"
  CERT_EMAIL="${CERT_EMAIL:-}"
  WEBSERVER="${WEBSERVER:-$(detect_webserver)}"
  [[ "$WEBSERVER" == "none" ]] && error "No running web server detected."
fi

# ── Preflight checks ──────────────────────────────────────────────────────────
section "Preflight"

# Port 80 must be reachable for ACME HTTP-01 challenge
if command -v ss &>/dev/null; then
  port80=$(ss -tlnp 2>/dev/null | grep ':80 ' || true)
elif command -v netstat &>/dev/null; then
  port80=$(netstat -tlnp 2>/dev/null | grep ':80 ' || true)
fi

if [[ -z "${port80:-}" ]]; then
  error "Port 80 is not listening. Let's Encrypt requires port 80 for the HTTP-01 challenge."
fi
success "Port 80 is open"

# Check DNS resolves to this server (best-effort)
SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || true)
DOMAIN_IP=$(getent hosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -1 || true)

if [[ -n "$SERVER_IP" && -n "$DOMAIN_IP" ]]; then
  if [[ "$SERVER_IP" == "$DOMAIN_IP" ]]; then
    success "DNS: $DOMAIN → $DOMAIN_IP (matches this server)"
  else
    warn "DNS mismatch: $DOMAIN resolves to $DOMAIN_IP but this server is $SERVER_IP"
    warn "Certificate issuance will fail if DNS does not point to this server."
    read -rp "  Continue anyway? [y/N] " DNS_OVERRIDE
    [[ "$DNS_OVERRIDE" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  fi
else
  warn "Could not verify DNS — proceeding anyway"
fi

# Check for existing certificate
if certbot certificates 2>/dev/null | grep -q "Domains:.*$DOMAIN"; then
  warn "Certificate already exists for $DOMAIN"
  read -rp "  Renew/expand existing certificate? [y/N] " RENEW
  [[ "$RENEW" =~ ^[Yy]$ ]] || { echo "Skipped."; exit 0; }
fi

# ── Install Certbot ───────────────────────────────────────────────────────────
section "Certbot"

if command -v certbot &>/dev/null; then
  warn "Certbot already installed — skipping"
else
  apt update -qq
  if [[ "$WEBSERVER" == "nginx" ]]; then
    apt install -y certbot python3-certbot-nginx
  else
    apt install -y certbot python3-certbot-apache
  fi
  success "Certbot installed"
fi

# ── Issue certificate ─────────────────────────────────────────────────────────
section "Certificate Issuance"

CERTBOT_DOMAINS="-d $DOMAIN"
[[ "$INCLUDE_WWW" =~ ^[Yy]$ ]] && CERTBOT_DOMAINS="$CERTBOT_DOMAINS -d www.$DOMAIN"

EMAIL_FLAG="--register-unsafely-without-email"
[[ -n "$CERT_EMAIL" ]] && EMAIL_FLAG="--email $CERT_EMAIL --no-eff-email"

log "Requesting certificate for $DOMAIN$([[ "$INCLUDE_WWW" =~ ^[Yy]$ ]] && echo " and www.$DOMAIN")..."

certbot "--$WEBSERVER" \
  $CERTBOT_DOMAINS \
  --non-interactive \
  --agree-tos \
  $EMAIL_FLAG \
  --redirect \
  --expand

success "Certificate issued and $WEBSERVER configured for HTTPS"

# ── Verify auto-renewal ───────────────────────────────────────────────────────
section "Auto-Renewal"

if systemctl is-enabled certbot.timer &>/dev/null; then
  success "Certbot systemd timer active — certificates renew automatically"
elif crontab -l 2>/dev/null | grep -q certbot; then
  success "Certbot cron job found — certificates renew automatically"
else
  warn "No auto-renewal timer found. Set one up:"
  warn "  echo '0 3 * * * certbot renew --quiet' | crontab -"
  warn "Or test renewal manually: certbot renew --dry-run"
fi

# ── Verify HTTPS ──────────────────────────────────────────────────────────────
section "Verification"

HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$DOMAIN" 2>/dev/null || true)
if [[ "$HTTPS_CODE" =~ ^[23] ]]; then
  success "HTTPS reachable: https://$DOMAIN (HTTP $HTTPS_CODE)"
else
  warn "HTTPS check returned HTTP $HTTPS_CODE — verify manually: https://$DOMAIN"
fi

EXPIRY=$(certbot certificates 2>/dev/null | grep -A3 "Domains:.*$DOMAIN" | grep "Expiry" | awk '{print $3, $4, $5}' || true)
[[ -n "$EXPIRY" ]] && success "Certificate expires: $EXPIRY"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SSL ready.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Domain  : https://$DOMAIN"
echo "  Renewal : automatic"
echo ""
