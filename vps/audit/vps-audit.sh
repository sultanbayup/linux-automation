#!/usr/bin/env bash
# vps-audit.sh — Read-only security audit for Ubuntu/Debian VPS.
# Checks common misconfigurations and prints a color-coded report.
# Run as: root (some checks require elevated access)

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()    { echo -e "  ${GREEN}[✓]${NC} $1"; }
fail()    { echo -e "  ${RED}[✗]${NC} $1"; ISSUES=$((ISSUES + 1)); }
warn()    { echo -e "  ${YELLOW}[!]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
info()    { echo -e "  ${BLUE}[i]${NC} $1"; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

ISSUES=0
WARNINGS=0

# ── Preflight ────────────────────────────────────────────────────────────────
[[ "$EUID" -ne 0 ]] && echo -e "${YELLOW}[!] Some checks require root. Run as root for full results.${NC}\n"

echo ""
echo -e "${BOLD}VPS Security Audit${NC} — $(hostname) — $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "OS: $(lsb_release -ds 2>/dev/null || uname -sr)"

# ── SSH ───────────────────────────────────────────────────────────────────────
section "SSH Configuration"

SSHD_CONFIG="/etc/ssh/sshd_config"

if [[ -f "$SSHD_CONFIG" ]]; then
  # Root login
  root_login=$(sshd -T 2>/dev/null | grep -i "^permitrootlogin" | awk '{print $2}' || grep -i "^PermitRootLogin" "$SSHD_CONFIG" | awk '{print $2}')
  if [[ "${root_login,,}" == "no" ]]; then
    pass "PermitRootLogin: no"
  else
    fail "PermitRootLogin: ${root_login:-not set} — root SSH login is allowed"
  fi

  # Password auth
  pass_auth=$(sshd -T 2>/dev/null | grep -i "^passwordauthentication" | awk '{print $2}' || grep -i "^PasswordAuthentication" "$SSHD_CONFIG" | awk '{print $2}')
  if [[ "${pass_auth,,}" == "no" ]]; then
    pass "PasswordAuthentication: no"
  else
    fail "PasswordAuthentication: ${pass_auth:-not set} — password login is enabled"
  fi

  # SSH port
  ssh_port=$(sshd -T 2>/dev/null | grep -i "^port " | awk '{print $2}' || echo "22")
  if [[ "$ssh_port" == "22" ]]; then
    warn "SSH running on default port 22 — consider changing to a non-standard port"
  else
    pass "SSH port: $ssh_port (non-default)"
  fi
else
  warn "sshd_config not found at $SSHD_CONFIG"
fi

# ── Firewall ──────────────────────────────────────────────────────────────────
section "Firewall"

if command -v ufw &>/dev/null; then
  ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
  if [[ "${ufw_status,,}" == "active" ]]; then
    pass "UFW: active"
    info "Open rules:"
    ufw status 2>/dev/null | grep -E "ALLOW|DENY" | while read -r line; do
      echo "       $line"
    done
  else
    fail "UFW: inactive — no firewall is running"
  fi
elif command -v iptables &>/dev/null; then
  rule_count=$(iptables -L 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT" || true)
  if [[ "$rule_count" -gt 0 ]]; then
    pass "iptables: $rule_count rules active"
  else
    warn "iptables: no rules found — firewall may not be configured"
  fi
else
  fail "No firewall detected (ufw or iptables)"
fi

# ── Users ─────────────────────────────────────────────────────────────────────
section "Users and Sudo"

# Accounts with sudo
info "Users with sudo access:"
getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' '\n' | while read -r u; do
  [[ -n "$u" ]] && echo "       $u"
done

# Passwordless sudo
pwless=$(grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#" || true)
if [[ -n "$pwless" ]]; then
  warn "Passwordless sudo entries found:"
  echo "$pwless" | while read -r line; do echo "       $line"; done
else
  pass "No passwordless sudo entries"
fi

# Users with UID 0 (root-equivalent)
uid0=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | grep -v "^root$" || true)
if [[ -n "$uid0" ]]; then
  fail "Non-root users with UID 0: $uid0"
else
  pass "No non-root users with UID 0"
fi

# ── Updates ───────────────────────────────────────────────────────────────────
section "Pending Updates"

if command -v apt &>/dev/null; then
  apt update -qq 2>/dev/null || true
  security_updates=$(apt list --upgradable 2>/dev/null | grep -c "security" || true)
  total_updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || true)

  if [[ "$security_updates" -gt 0 ]]; then
    fail "$security_updates security update(s) pending"
  else
    pass "No pending security updates"
  fi

  if [[ "$total_updates" -gt 0 ]]; then
    warn "$total_updates total package update(s) available"
  fi

  # Unattended upgrades
  if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    auto=$(grep -c 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades || true)
    if [[ "$auto" -gt 0 ]]; then
      pass "Automatic security updates: enabled"
    else
      warn "Automatic security updates: configured but not enabled"
    fi
  else
    warn "Automatic security updates: not configured"
  fi
fi

# ── Services ──────────────────────────────────────────────────────────────────
section "Running Services and Open Ports"

info "Listening ports (TCP):"
if command -v ss &>/dev/null; then
  ss -tlnp 2>/dev/null | tail -n +2 | while read -r line; do
    echo "       $line"
  done
elif command -v netstat &>/dev/null; then
  netstat -tlnp 2>/dev/null | tail -n +3 | while read -r line; do
    echo "       $line"
  done
fi

# Fail2ban
if systemctl is-active --quiet fail2ban 2>/dev/null; then
  pass "Fail2ban: active"
else
  fail "Fail2ban: not running — no brute-force protection"
fi

# ── Filesystem ────────────────────────────────────────────────────────────────
section "Filesystem"

# World-writable files in /etc
ww_etc=$(find /etc -maxdepth 2 -perm -o+w -type f 2>/dev/null | head -5 || true)
if [[ -n "$ww_etc" ]]; then
  warn "World-writable files in /etc:"
  echo "$ww_etc" | while read -r f; do echo "       $f"; done
else
  pass "No world-writable files in /etc"
fi

# SUID binaries (informational)
suid_count=$(find / -xdev -perm -4000 -type f 2>/dev/null | wc -l || true)
info "SUID binaries found: $suid_count (informational — review if unexpected)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Audit Summary${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ "$ISSUES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}All checks passed. No issues found.${NC}"
elif [[ "$ISSUES" -eq 0 ]]; then
  echo -e "  ${YELLOW}${BOLD}$WARNINGS warning(s) — no critical issues.${NC}"
else
  echo -e "  ${RED}${BOLD}$ISSUES issue(s) found, $WARNINGS warning(s).${NC}"
  echo -e "  ${RED}Review the [✗] items above and remediate.${NC}"
fi

echo ""
