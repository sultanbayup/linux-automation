# backup/

Scripts for automated database and file backups.

---

## Scripts

### `db-backup.sh`

Automated MySQL backup with daily/weekly/monthly retention and optional GCS upload. Designed to run unattended via cron.

**Recommended — use `~/.my.cnf` instead of passing credentials inline:**

```bash
# Create credentials file (do this once)
cat > ~/.my.cnf << 'EOF'
[client]
user=root
password=yourpassword
host=localhost
EOF
chmod 600 ~/.my.cnf

# Then run without any credentials
DB_NAME=mydb bash backup/db-backup.sh
```

**Or pass credentials inline (for quick testing only):**

```bash
# Set your credentials and run
DB_USER=root DB_PASS=secret DB_NAME=mydb bash backup/db-backup.sh
```

**Cron setup (runs daily at 2am) — assumes `~/.my.cnf` is configured:**

```bash
0 2 * * * DB_NAME=mydb /path/to/db-backup.sh >> /var/log/db-backup.log 2>&1
```

**Configuration** — edit the variables at the top of the script or export them as environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_USER` | `root` | MySQL user |
| `DB_PASS` | _(empty)_ | MySQL password — leave empty to use `~/.my.cnf` (recommended) |
| `DB_HOST` | `localhost` | MySQL host |
| `DB_NAME` | _(empty)_ | Database to back up — leave empty to back up all |
| `BACKUP_DIR` | `/var/backups/mysql` | Local backup destination |
| `KEEP_DAILY` | `7` | Daily backups to keep |
| `KEEP_WEEKLY` | `4` | Weekly backups to keep |
| `KEEP_MONTHLY` | `3` | Monthly backups to keep |
| `GCS_BUCKET` | _(empty)_ | GCS bucket URI — leave empty to skip upload |

For full details → [sultanbp.com/blog/automating-mysql-backups-to-gcs](https://sultanbp.com/blog/automating-mysql-backups-to-gcs/)
