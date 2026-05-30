#!/usr/bin/env bash
# db-backup.sh — Automated MySQL backup with retention and optional GCS upload.
# Blog: https://sultanbp.com/blog/automating-mysql-backups-to-gcs/
# Run as: root or a user with MySQL access
# Cron example: 0 2 * * * /path/to/db-backup.sh >> /var/log/db-backup.log 2>&1

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
# Edit these values or export them as environment variables before running.

DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"                  # Leave empty to use ~/.my.cnf or socket auth
DB_HOST="${DB_HOST:-localhost}"
DB_NAME="${DB_NAME:-}"                  # Leave empty to back up ALL databases

BACKUP_DIR="${BACKUP_DIR:-/var/backups/mysql}"

# Retention: how many backups to keep per tier
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-3}"

# Optional GCS upload — leave empty to skip
GCS_BUCKET="${GCS_BUCKET:-}"           # e.g. gs://my-bucket/db-backups

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()     { echo -e "${BLUE}[db-backup]${NC} [$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────────────
command -v mysqldump &>/dev/null || error "mysqldump not found. Install mariadb-client or mysql-client."
command -v gzip      &>/dev/null || error "gzip not found."

if [[ -n "$GCS_BUCKET" ]]; then
  command -v gsutil &>/dev/null || error "gsutil not found but GCS_BUCKET is set. Install google-cloud-sdk."
fi

mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly}

# ── MySQL connection args ─────────────────────────────────────────────────────
MYSQL_ARGS="-h $DB_HOST -u $DB_USER"
[[ -n "$DB_PASS" ]] && MYSQL_ARGS="$MYSQL_ARGS -p$DB_PASS"

# ── Determine databases to back up ───────────────────────────────────────────
if [[ -n "$DB_NAME" ]]; then
  DATABASES="$DB_NAME"
else
  log "No DB_NAME set — backing up all databases..."
  DATABASES=$(mysql $MYSQL_ARGS -e "SHOW DATABASES;" 2>/dev/null \
    | grep -Ev "^(Database|information_schema|performance_schema|sys)$")
fi

# ── Determine backup tier ─────────────────────────────────────────────────────
# Monthly: 1st of the month. Weekly: Sunday. Daily: everything else.
DAY_OF_MONTH=$(date +%d)
DAY_OF_WEEK=$(date +%u)   # 1=Mon ... 7=Sun

if [[ "$DAY_OF_MONTH" == "01" ]]; then
  TIER="monthly"
elif [[ "$DAY_OF_WEEK" == "7" ]]; then
  TIER="weekly"
else
  TIER="daily"
fi

DATE=$(date +%Y-%m-%d)
log "Backup tier: $TIER | Date: $DATE"

# ── Dump ─────────────────────────────────────────────────────────────────────
BACKED_UP=()

for db in $DATABASES; do
  FILENAME="${db}_${DATE}.sql.gz"
  DEST="$BACKUP_DIR/$TIER/$FILENAME"

  log "Dumping: $db → $DEST"

  mysqldump $MYSQL_ARGS \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    "$db" 2>/dev/null \
    | gzip > "$DEST"

  success "$db backed up ($(du -sh "$DEST" | cut -f1))"
  BACKED_UP+=("$DEST")
done

# ── GCS upload ────────────────────────────────────────────────────────────────
if [[ -n "$GCS_BUCKET" ]]; then
  log "Uploading to GCS: $GCS_BUCKET/$TIER/"
  for file in "${BACKED_UP[@]}"; do
    gsutil cp "$file" "$GCS_BUCKET/$TIER/" \
      && success "Uploaded: $(basename "$file")" \
      || warn "Upload failed: $(basename "$file")"
  done
fi

# ── Retention cleanup ─────────────────────────────────────────────────────────
log "Applying retention policy..."

cleanup_tier() {
  local tier="$1"
  local keep="$2"
  local dir="$BACKUP_DIR/$tier"

  # Count files per database and remove oldest beyond the keep limit
  for db in $DATABASES; do
    local files
    files=$(ls -t "$dir/${db}_"*.sql.gz 2>/dev/null || true)
    local count
    count=$(echo "$files" | grep -c . || true)

    if [[ "$count" -gt "$keep" ]]; then
      echo "$files" | tail -n +"$((keep + 1))" | while read -r old; do
        rm -f "$old"
        warn "Removed old backup: $(basename "$old")"
      done
    fi
  done
}

cleanup_tier "daily"   "$KEEP_DAILY"
cleanup_tier "weekly"  "$KEEP_WEEKLY"
cleanup_tier "monthly" "$KEEP_MONTHLY"

success "Retention applied (daily: $KEEP_DAILY, weekly: $KEEP_WEEKLY, monthly: $KEEP_MONTHLY)"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Backup complete.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Tier      : $TIER"
echo "  Location  : $BACKUP_DIR/$TIER/"
echo "  Databases : ${BACKED_UP[*]:-none}"
[[ -n "$GCS_BUCKET" ]] && echo "  GCS       : $GCS_BUCKET/$TIER/"
echo ""
echo "  Blog: https://sultanbp.com/blog/automating-mysql-backups-to-gcs/"
echo ""
