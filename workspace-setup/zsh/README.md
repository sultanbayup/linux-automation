# workspace-setup/zsh/

Zsh setup — installs Oh My Zsh, Powerlevel10k, plugins, and writes dotfiles.

---

## What's included

| File | Purpose |
|------|---------|
| `setup-zsh.sh` | Installer — runs everything in one command |
| `.zshrc` | Configured `.zshrc` template |
| `.zsh_aliases` | Aliases for git, kubectl, terraform, navigation |
| `.zsh_functions` | Shell functions — k8s helpers, fzf workflows, system utils |

---

## How to use

**Run as your regular user (not root):**

```bash
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/workspace-setup/zsh/setup-zsh.sh | bash
```

Or locally:

```bash
bash workspace-setup/zsh/setup-zsh.sh
```

**After the script finishes:**

```bash
# Set Zsh as your default shell
chsh -s $(which zsh)

# Open a new terminal, then configure the prompt
p10k configure
```

For full details → [sultanbp.com/docs/linux/zsh-setup-and-plugins](https://sultanbp.com/docs/linux/zsh-setup-and-plugins/)
