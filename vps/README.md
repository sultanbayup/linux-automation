# vps/

Scripts for VPS initial setup and hardening on Ubuntu/Debian.

---

## Scripts

### `setup-vps.sh`

Full VPS setup in one command — creates a sudo user, hardens SSH, configures UFW firewall, installs Fail2ban, enables automatic security updates, installs Docker, and writes a custom MOTD.

**Run as root on a fresh server:**

```bash
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/vps/setup-vps.sh | bash
```

Or locally:

```bash
bash vps/setup-vps.sh
```

The script will prompt for username, hostname, and timezone before making any changes.

For full details → [sultanbp.com/docs/linux/vps-setup-hardening](https://sultanbp.com/docs/linux/vps-setup-hardening)
