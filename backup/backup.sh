#!/usr/bin/env bash
# GLPI stack backup — database + uploaded files + config.
# Run from the glpi-stack project directory, or set PROJECT_DIR below.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/glpi-backups}"
DATE="$(date +%F_%H%M%S)"
DEST="$BACKUP_ROOT/$DATE"
KEEP_DAYS="${KEEP_DAYS:-14}"   # how many days of backups to retain locally

# Paste the Apps Script Web App URL here (see apps-script.gs).
# Leave blank to skip Google Sheets logging entirely.
SHEET_WEBHOOK_URL="${SHEET_WEBHOOK_URL:-}"

log_to_sheet() {
  local status="$1" db_size="$2" files_size="$3"
  if [ -n "$SHEET_WEBHOOK_URL" ]; then
    curl -s -X POST "$SHEET_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"status\":\"$status\",\"db_size\":\"$db_size\",\"files_size\":\"$files_size\",\"backup_path\":\"$DEST\"}" \
      > /dev/null || echo "WARNING: could not reach Google Sheets webhook"
  fi
}

# Optional: rclone remote name (e.g. "gdrive") to sync backups to.
# Leave blank to skip offsite sync.
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
RCLONE_PATH="${RCLONE_PATH:-glpi-backups}"

sync_to_remote() {
  if [ -n "$RCLONE_REMOTE" ]; then
    echo ">> Syncing to remote ($RCLONE_REMOTE:$RCLONE_PATH/$DATE)..."
    if rclone copy "$DEST" "$RCLONE_REMOTE:$RCLONE_PATH/$DATE" --quiet; then
      echo ">> Remote sync complete."
    else
      echo "WARNING: remote sync failed — local backup is still safe."
    fi
  fi
}

cd "$PROJECT_DIR"
source .env

# Log a failure to the sheet if any step below fails unexpectedly.
trap 'log_to_sheet "FAILED" "-" "-"' ERR

mkdir -p "$DEST"

echo ">> Backing up database..."
docker exec glpi-db mariadb-dump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  | gzip > "$DEST/glpi-db.sql.gz"

echo ">> Backing up uploaded files volume..."
docker run --rm \
  -v glpi-stack_glpi_files:/data:ro \
  -v "$DEST":/backup \
  alpine tar czf /backup/glpi-files.tar.gz -C /data .

echo ">> Backing up GLPI config volume..."
docker run --rm \
  -v glpi-stack_glpi_config:/data:ro \
  -v "$DEST":/backup \
  alpine tar czf /backup/glpi-config.tar.gz -C /data .

echo ">> Backing up config files..."
cp .env "$DEST/.env"
cp docker-compose.yml "$DEST/docker-compose.yml"

DB_SIZE=$(du -h "$DEST/glpi-db.sql.gz" | cut -f1)
FILES_SIZE=$(du -h "$DEST/glpi-files.tar.gz" | cut -f1)

echo ">> Backup complete: $DEST"
log_to_sheet "SUCCESS" "$DB_SIZE" "$FILES_SIZE"
sync_to_remote

echo ">> Pruning backups older than $KEEP_DAYS days..."
find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} \;

echo ">> Current backups:"
ls -la "$BACKUP_ROOT"

