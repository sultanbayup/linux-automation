# vps/setup/

Full VPS setup and hardening in one command.

---

## `setup-vps.sh`

Creates a sudo user, hardens SSH, configures UFW firewall, installs Fail2ban, enables automatic security updates, installs Docker, and writes a custom MOTD.

**Run as root on a fresh server:**

```bash
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/vps/setup/setup-vps.sh | bash
```

Or locally:

```bash
bash vps/setup/setup-vps.sh
```

The script prompts for username, hostname, and timezone before making any changes.

For full details → [sultanbp.com/docs/linux/vps-setup-hardening](https://sultanbp.com/docs/linux/vps-setup-hardening/)
