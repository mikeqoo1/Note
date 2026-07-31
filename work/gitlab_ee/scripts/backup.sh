#!/usr/bin/env bash
# GitLab 完整備份：應用資料（gitlab-backup）+ secrets/設定檔
# 用法：./scripts/backup.sh   （可排 cron，例：0 2 * * * cd <本目錄>/.. && ./scripts/backup.sh）
#
# 重要：gitlab-backup 產生的 tar「不含」gitlab-secrets.json 與 gitlab.rb，
#       兩者遺失的話 CI variables / 2FA / runner token 等加密資料救不回來，
#       所以本腳本會把它們一併拷到 SECRET_BACKUP_DIR。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJ_DIR}"

# shellcheck disable=SC1091
source .env

CONTAINER="${GITLAB_CONTAINER_NAME:-gitlab-ee}"
TS="$(date +%Y%m%d-%H%M%S)"

# ---------- 應用資料備份 ----------
# STRATEGY=copy：先複製再打包，避免備份期間檔案變動導致失敗
echo ">>> [1/3] gitlab-backup create（產出在 ${GITLAB_HOME}/data/backups/）"
docker compose exec -T gitlab gitlab-backup create STRATEGY=copy

# ---------- secrets / 設定檔備份 ----------
echo ">>> [2/3] 備份 gitlab-secrets.json / gitlab.rb → ${SECRET_BACKUP_DIR}"
mkdir -p "${SECRET_BACKUP_DIR}"
cp -a "${GITLAB_HOME}/config/gitlab-secrets.json" "${SECRET_BACKUP_DIR}/gitlab-secrets.json.${TS}"
cp -a "${GITLAB_HOME}/config/gitlab.rb" "${SECRET_BACKUP_DIR}/gitlab.rb.${TS}" 2>/dev/null || \
  echo "    （gitlab.rb 不存在，設定全走 GITLAB_OMNIBUS_CONFIG，略過）"
chmod 600 "${SECRET_BACKUP_DIR}/gitlab-secrets.json.${TS}"

# ---------- 清舊備份 ----------
# tar 檔由 gitlab.rb 的 backup_keep_time 自動清；這裡清 secrets 舊拷貝
echo ">>> [3/3] 清除 ${BACKUP_KEEP_DAYS:-7} 天前的 secrets 備份"
find "${SECRET_BACKUP_DIR}" -name 'gitlab-secrets.json.*' -mtime "+${BACKUP_KEEP_DAYS:-7}" -delete
find "${SECRET_BACKUP_DIR}" -name 'gitlab.rb.*' -mtime "+${BACKUP_KEEP_DAYS:-7}" -delete

echo ">>> 完成。目前備份清單："
ls -lh "${GITLAB_HOME}/data/backups/" | tail -n 10
