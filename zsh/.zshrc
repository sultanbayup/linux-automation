# ── Oh My Zsh ────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

plugins=(
  git
  kubectl
  terraform
  docker
  fzf
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ── Environment ──────────────────────────────────────────────
export EDITOR="vim"
export PATH="$HOME/.local/bin:$PATH"

# ── Aliases ──────────────────────────────────────────────────
[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases

# ── Functions ────────────────────────────────────────────────
[[ -f ~/.zsh_functions ]] && source ~/.zsh_functions

# ── Tools ────────────────────────────────────────────────────
eval "$(zoxide init zsh)"

# ── p10k ─────────────────────────────────────────────────────
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
