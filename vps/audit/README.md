# vps/audit/

Read-only security audit for Ubuntu/Debian servers.

---

## `vps-audit.sh`

Scans common security misconfigurations and prints a color-coded report. Safe to run on any server — makes no changes.

**Checks:**
- SSH: root login, password auth, default port
- Firewall: UFW status, open rules
- Users: sudo access, passwordless sudo, UID 0 accounts
- Updates: pending security updates, unattended-upgrades status
- Services: listening ports, Fail2ban status
- Filesystem: world-writable files in `/etc`, SUID binary count

**Run as root for full results:**

```bash
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/vps/audit/vps-audit.sh | bash
```

Or locally:

```bash
bash vps/audit/vps-audit.sh
```

No prompts. Outputs a report and exits. Non-zero exit if critical issues are found.
