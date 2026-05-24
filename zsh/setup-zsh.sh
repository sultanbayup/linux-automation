#!/usr/bin/env bash
# =============================================================================
# setup-zsh.sh
# Zsh setup script — installs zsh, Oh My Zsh, Powerlevel10k, and plugins.
# Companion doc: https://sultanbp.com/docs/linux/zsh-setup-and-plugins
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/zsh/setup-zsh.sh | bash
#
# What this script does:
#   1. Installs zsh, curl, git, fzf
#   2. Installs Oh My Zsh (unattended)
#   3. Installs Powerlevel10k theme
#   4. Installs zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions
#   5. Installs zoxide
#   6. Writes ~/.zshrc, ~/.zsh_aliases, ~/.zsh_functions from this repo
#
# What this script does NOT do:
#   - Set zsh as your default shell (run: chsh -s $(which zsh))
#   - Configure Powerlevel10k prompt style (run: p10k configure)
#   - Install a Nerd Font (do this in your terminal emulator settings)
# =============================================================================

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/sultanbayup/linux-automation/main/zsh"

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

# ── Checks ───────────────────────────────────────────────────────────────────
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  error "This script targets Linux (Ubuntu/Debian). Detected: $OSTYPE"
fi

if ! command -v apt &>/dev/null; then
  error "apt not found. This script requires a Debian-based distro."
fi

# ── Step 1: System packages ──────────────────────────────────────────────────
log "Installing system packages (zsh, curl, git, fzf)..."
sudo apt update -qq
sudo apt install -y zsh curl git fzf
success "System packages installed"

# ── Step 2: Oh My Zsh ────────────────────────────────────────────────────────
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  warn "Oh My Zsh already installed — skipping"
else
  log "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── Step 3: Powerlevel10k ────────────────────────────────────────────────────
P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  warn "Powerlevel10k already installed — skipping"
else
  log "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  success "Powerlevel10k installed"
fi

# ── Step 4: Plugins ──────────────────────────────────────────────────────────
install_plugin() {
  local name="$1"
  local repo="$2"
  local dest="$ZSH_CUSTOM/plugins/$name"

  if [[ -d "$dest" ]]; then
    warn "Plugin '$name' already installed — skipping"
  else
    log "Installing plugin: $name..."
    git clone "$repo" "$dest"
    success "Plugin '$name' installed"
  fi
}

install_plugin "zsh-autosuggestions" \
  "https://github.com/zsh-users/zsh-autosuggestions"

install_plugin "zsh-syntax-highlighting" \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git"

install_plugin "zsh-completions" \
  "https://github.com/zsh-users/zsh-completions"

# ── Step 5: zoxide ───────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  warn "zoxide already installed — skipping"
else
  log "Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  success "zoxide installed"
fi

# ── Step 6: Dotfiles ─────────────────────────────────────────────────────────
backup_if_exists() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Existing $file found — backing up to $backup"
    cp "$file" "$backup"
  fi
}

log "Writing dotfiles from repo..."

backup_if_exists "$HOME/.zshrc"
curl -fsSL "$REPO_RAW/.zshrc" -o "$HOME/.zshrc"
success "~/.zshrc written"

backup_if_exists "$HOME/.zsh_aliases"
curl -fsSL "$REPO_RAW/.zsh_aliases" -o "$HOME/.zsh_aliases"
success "~/.zsh_aliases written"

backup_if_exists "$HOME/.zsh_functions"
curl -fsSL "$REPO_RAW/.zsh_functions" -o "$HOME/.zsh_functions"
success "~/.zsh_functions written"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Set zsh as your default shell:"
echo "     chsh -s \$(which zsh)"
echo ""
echo "  2. Install a Nerd Font in your terminal emulator"
echo "     Recommended: MesloLGS NF — https://www.nerdfonts.com/"
echo ""
echo "  3. Open a new terminal session, then run:"
echo "     p10k configure"
echo ""
echo "  Full docs: https://sultanbp.com/docs/linux/zsh-setup-and-plugins"
echo ""
