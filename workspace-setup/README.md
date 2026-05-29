# workspace-setup/

Scripts for setting up a local development environment and shell configuration.

---

## Subfolders

### `zsh/`

Installs and configures Zsh with Oh My Zsh, Powerlevel10k theme, plugins, and dotfiles (aliases, functions).

**Run as your regular user:**

```bash
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/workspace-setup/zsh/setup-zsh.sh | bash
```

Or locally:

```bash
bash workspace-setup/zsh/setup-zsh.sh
```

After the script finishes, set Zsh as your default shell and run `p10k configure` to set up the prompt.

For full details → [sultanbp.com/docs/linux/zsh-setup-and-plugins](https://sultanbp.com/docs/linux/zsh-setup-and-plugins)
