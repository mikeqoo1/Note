#!/usr/bin/env bash
set -e

PLANE_HOME="/opt/plane"
BACKUP_DATE="$(date +%F)"
BACKUP_FILE="plane-backup-${BACKUP_DATE}.tar.gz"

# 社群版主機資訊
CE_USER="mike"
CE_HOST="192.168.103.150"          # ← 這裡換成你的社群版 IP
CE_TARGET_DIR="/Projects/plane-selfhost"

cd "$PLANE_HOME"

echo "==> Creating backup archive: ${BACKUP_FILE}"
tar czvf "${BACKUP_FILE}" data/

echo "==> Transfer backup to community host"
scp "${BACKUP_FILE}" "${CE_USER}@${CE_HOST}:${CE_TARGET_DIR}/"

echo "==> Done"
echo "Backup file: ${BACKUP_FILE}"
