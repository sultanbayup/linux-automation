# linux-automation

A collection of shell scripts for automating Linux server setup, hardening, and workspace configuration. Each script is a companion to a docs page on [sultanbp.com](https://sultanbp.com/docs/linux/).

Scripts are designed to be idempotent, transparent, and runnable with a single command.

---

## Scripts

| Script | What it does |
|--------|-------------|
| [`vps/setup-vps.sh`](vps/) | Full VPS setup — user, SSH hardening, UFW, Fail2ban, Docker |
| [`workspace-setup/zsh/setup-zsh.sh`](workspace-setup/zsh/) | Zsh + Oh My Zsh + Powerlevel10k + plugins + dotfiles |

---

## Structure

```
linux-automation/
├── vps/                        # VPS setup and hardening
├── workspace-setup/
│   └── zsh/                    # Zsh environment setup
└── TODO/                       # Planned scripts and portfolio roadmap
```

---

## Usage

All scripts can be run directly via curl or cloned and run locally. See the README in each folder for the exact command.

---

## Requirements

- Ubuntu 22.04+ or Debian 11+
- `bash` 4.0+
- `sudo` access (or root for `setup-vps.sh`)

---

## License

MIT
