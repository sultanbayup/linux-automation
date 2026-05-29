#!/usr/bin/env bash
# setup-zsh.sh — Zsh + Oh My Zsh + Powerlevel10k + plugins + dotfiles.
# Docs: https://sultanbp.com/docs/linux/zsh-setup-and-plugins
# Run as: regular user (not root)

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/sultanbayup/linux-automation/main/workspace-setup/zsh"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[zsh-setup]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────────────
[[ "$OSTYPE" == "linux-gnu"* ]] || error "This script targets Linux. Detected: $OSTYPE"
command -v apt &>/dev/null      || error "apt not found. Requires a Debian-based distro."

# ── System packages ──────────────────────────────────────────────────────────
log "Installing zsh, curl, git, fzf..."
sudo apt update -qq
sudo apt install -y zsh curl git fzf
success "System packages installed"

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  warn "Oh My Zsh already installed — skipping"
else
  log "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── Powerlevel10k ────────────────────────────────────────────────────────────
P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  warn "Powerlevel10k already installed — skipping"
else
  log "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  success "Powerlevel10k installed"
fi

# ── Plugins ──────────────────────────────────────────────────────────────────
install_plugin() {
  local name="$1" repo="$2" dest="$ZSH_CUSTOM/plugins/$1"
  if [[ -d "$dest" ]]; then
    warn "Plugin '$name' already installed — skipping"
  else
    log "Installing $name..."
    git clone "$repo" "$dest"
    success "$name installed"
  fi
}

install_plugin "zsh-autosuggestions"    "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
install_plugin "zsh-completions"        "https://github.com/zsh-users/zsh-completions"

# ── zoxide ───────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  warn "zoxide already installed — skipping"
else
  log "Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  success "zoxide installed"
fi

# ── Dotfiles ─────────────────────────────────────────────────────────────────
backup_if_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Backing up $file → $backup"
    cp "$file" "$backup"
  fi
}

log "Writing dotfiles..."

for dotfile in .zshrc .zsh_aliases .zsh_functions; do
  backup_if_exists "$HOME/$dotfile"
  curl -fsSL "$REPO_RAW/$dotfile" -o "$HOME/$dotfile"
  sed -i 's/\r//' "$HOME/$dotfile"
  success "$dotfile written"
done

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next:"
echo "  1. Set Zsh as default shell: chsh -s \$(which zsh)"
echo "  2. Install a Nerd Font in your terminal (recommended: MesloLGS NF)"
echo "  3. Open a new terminal, then run: p10k configure"
echo ""
echo "  Docs: https://sultanbp.com/docs/linux/zsh-setup-and-plugins"
echo ""
