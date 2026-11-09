#!/bin/bash

# Backup
# Backs up the database and the API logs. Run by cron as the book-api user.

# Stop on errors, also if a command in the middle of a pipe fails
set -eo pipefail

# Settings
PROJECT_DIR="/home/book-api/book-api"
BACKUP_DIR="/home/book-api/backups"
KEEP_DAYS=7
STAMP="$(date +%Y-%m-%d_%H%M)"

# New files are readable only by the owner (600)
umask 077

# Create the backup folder and go to the project, where docker-compose.yml is
mkdir -p "$BACKUP_DIR"
cd "$PROJECT_DIR"

# Database
# pg_dump runs inside the db container and writes the database as SQL
# --clean --if-exists makes the backup restorable over an existing database
# gzip compresses it on the server
docker compose exec -T db sh -c 'pg_dump --clean --if-exists -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
    | gzip > "$BACKUP_DIR/db_$STAMP.sql.gz"

# Logs
# Everything the API container logged the last 24 hours
docker compose logs --no-color --since 24h api | gzip > "$BACKUP_DIR/api-log_$STAMP.txt.gz"

# Cleanup
# Delete backups older than KEEP_DAYS so the disk does not fill up
find "$BACKUP_DIR" -type f -mtime +"$KEEP_DAYS" -delete

echo "$(date '+%F %T') Backup done: $STAMP"
