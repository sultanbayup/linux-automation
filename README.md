# linux-automation

A collection of shell scripts for automating Linux server setup, hardening, and workspace configuration. Each script is a companion to a docs page on [sultanbp.com](https://sultanbp.com/docs/linux/).

Scripts are designed to be idempotent, transparent, and runnable with a single command.

---

## Scripts

| Script | What it does |
|--------|-------------|
| [`vps/setup/setup-vps.sh`](vps/setup/) | Full VPS setup — user, SSH hardening, UFW, Fail2ban, Docker |
| [`vps/audit/vps-audit.sh`](vps/audit/) | Read-only security audit — color-coded report of misconfigurations |
| [`web/lemp/nginx-lemp.sh`](web/lemp/) | One-command LEMP stack — Nginx, PHP-FPM, MariaDB, optional SSL |
| [`web/ssl/ssl-auto.sh`](web/ssl/) | Standalone SSL automation — works with any running Nginx or Apache |
| [`backup/db-backup.sh`](backup/) | Automated MySQL backup with daily/weekly/monthly retention and optional GCS upload |
| [`workspace-setup/zsh/setup-zsh.sh`](workspace-setup/zsh/) | Zsh + Oh My Zsh + Powerlevel10k + plugins + dotfiles |

---

## Why These Scripts Exist

**VPS setup is repetitive and easy to get wrong.** Every new server needs the same baseline: a non-root user, SSH hardening, a firewall, brute-force protection, Docker. Doing it manually takes 20–30 minutes and it's easy to miss a step — especially the order-sensitive ones like allowing SSH before enabling UFW. `setup-vps.sh` and `nginx-lemp.sh` handle this in one command so you can go from a blank Ubuntu server to a hardened, production-ready environment without thinking through the sequence every time.

**Databases need checkpoints, not just backups.** A backup that runs once and lives on the same server isn't a backup — it's a copy. `db-backup.sh` runs on a cron schedule, applies daily/weekly/monthly retention automatically, and optionally ships backups offsite to GCS. If you're already on GCP, your database backups end up in the same ecosystem as the rest of your infrastructure.

---

## Real-World Use Cases

- **Deploying an app to a new VPS** — run `setup-vps.sh` first, then `nginx-lemp.sh` for the web stack. Server is hardened and serving HTTPS in under 10 minutes
- **WordPress / Laravel on Ubuntu** — `nginx-lemp.sh` handles Nginx, PHP-FPM, MariaDB, and Let's Encrypt SSL in one interactive run
- **Automated database protection** — schedule `db-backup.sh` via cron, point `GCS_BUCKET` at your bucket, and your MySQL databases are backed up offsite every night with automatic retention cleanup
- **Consistent dev environment** — `setup-zsh.sh` replicates the same Zsh setup across machines in one command

---

## What This Demonstrates

- **Idempotency** — scripts check state before acting; safe to re-run on partially configured servers
- **Error handling** — `set -euo pipefail` throughout; failures exit with a clear message rather than continuing into a broken state
- **GCS integration** — `db-backup.sh` uses `gsutil` to ship backups to Google Cloud Storage
- **SSL automation** — `ssl-auto.sh` handles Let's Encrypt certificate issuance, auto-renewal verification, and DNS preflight checks; `nginx-lemp.sh` delegates to it rather than duplicating the logic
- **Cron-ready design** — `db-backup.sh` runs fully unattended with no interactive input; suitable for scheduled execution
- **Security-first defaults** — `setup-vps.sh` disables root SSH login and password auth before the firewall is enabled

---

## Structure

```
linux-automation/
├── vps/
│   ├── setup/                  # VPS setup and hardening
│   └── audit/                  # Security audit scanner
├── web/
│   ├── lemp/                   # LEMP stack (Nginx + PHP-FPM + MariaDB)
│   └── ssl/                    # SSL certificate automation
├── backup/                     # Database backup automation
└── workspace-setup/
    └── zsh/                    # Zsh environment setup
```

---

## Requirements

- Ubuntu 22.04+ or Debian 11+
- `bash` 4.0+
- `sudo` access (or root for `setup-vps.sh` and `nginx-lemp.sh`)

---

## License

MIT
