# linux-automation

A collection of shell scripts for automating common Linux server setup tasks. Each script is a companion to a doc on [sultanbp.com](https://sultanbp.com/docs/linux/).

The idea is simple — the docs explain what is happening and why, the scripts handle the execution. Read the doc once, run the script everywhere.

---

## Scripts

| Script | What it does | Doc |
|--------|-------------|-----|
| `vps/setup-vps.sh` | Full VPS initial setup — user, SSH hardening, UFW, Fail2ban, Docker | [VPS Setup and Hardening](https://sultanbp.com/docs/linux/vps-setup-hardening) |
| `zsh/setup-zsh.sh` | Zsh + Oh My Zsh + Powerlevel10k + plugins + aliases + functions | [Zsh Setup and Plugins](https://sultanbp.com/docs/linux/zsh-setup-and-plugins) |

---

## Usage

All scripts are designed to be run directly via curl:

```bash
# VPS initial setup (run as root on a fresh server)
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/vps/setup-vps.sh | bash

# Zsh setup (run as your regular user)
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/zsh/setup-zsh.sh | bash
```

Or clone the repo and run locally:

```bash
git clone https://github.com/sultanbayup/linux-automation.git
cd linux-automation

bash vps/setup-vps.sh
bash zsh/setup-zsh.sh
```

---

## Design Principles

- **Idempotent** — safe to run multiple times. Already-installed components are skipped.
- **Input variables** — scripts prompt for user-specific values (username, hostname, timezone) rather than hardcoding them.
- **Transparent** — every step is logged. No silent failures.
- **Companion docs** — each script maps to a doc that explains the reasoning behind each step.

---

## Structure

```
linux-automation/
  vps/
    setup-vps.sh        # VPS initial setup and hardening
  zsh/
    setup-zsh.sh        # Zsh + Oh My Zsh + plugins
    .zshrc              # Configured .zshrc template
    .zsh_aliases        # Aliases (git, kubectl, terraform, navigation)
    .zsh_functions      # Shell functions (k8s helpers, fzf workflows, etc.)
  README.md
```

---

## Planned

- `k8s/setup-kubectl.sh` — kubectl, kubeconfig helpers, completions
- `gcp/setup-gcloud.sh` — gcloud SDK, project init, auth
- `docker/setup-docker.sh` — Docker + Compose standalone install
- `monitoring/setup-node-exporter.sh` — Prometheus node exporter

---

## Requirements

- Ubuntu 22.04+ or Debian 11+
- `bash` 4.0+
- `sudo` access (or root for `setup-vps.sh`)

---

## License

MIT
