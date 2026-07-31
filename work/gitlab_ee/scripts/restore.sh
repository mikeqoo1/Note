#!/usr/bin/env bash
# 從 gitlab-backup 產生的 tar 還原
# 用法：./scripts/restore.sh <BACKUP_ID>
#   BACKUP_ID 是 tar 檔名去掉尾巴 _gitlab_backup.tar 的部分，
#   例：檔名 1722310000_2026_07_30_19.2.1-ee_gitlab_backup.tar
#       → ./scripts/restore.sh 1722310000_2026_07_30_19.2.1-ee
#
# 前提：
#   1. 目標 GitLab 版本必須與備份時「完全相同」
#   2. gitlab-secrets.json 必須先放回 ${GITLAB_HOME}/config/（否則加密資料解不開）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJ_DIR}"

# shellcheck disable=SC1091
source .env

if [[ $# -ne 1 ]]; then
  echo "用法：$0 <BACKUP_ID>" >&2
  echo "可用備份：" >&2
  ls "${GITLAB_HOME}/data/backups/" >&2
  exit 1
fi
BACKUP_ID="$1"

if [[ ! -f "${GITLAB_HOME}/data/backups/${BACKUP_ID}_gitlab_backup.tar" ]]; then
  echo "錯誤：找不到 ${GITLAB_HOME}/data/backups/${BACKUP_ID}_gitlab_backup.tar" >&2
  exit 1
fi

echo "!!! 還原會覆蓋現有全部資料（repo、DB、上傳檔案），無法復原 !!!"
read -r -p "輸入 yes 繼續：" CONFIRM
[[ "${CONFIRM}" == "yes" ]] || { echo "已取消"; exit 1; }

# ---------- 停掉會連 DB 的服務 ----------
echo ">>> 停止 puma / sidekiq"
docker compose exec -T gitlab gitlab-ctl stop puma
docker compose exec -T gitlab gitlab-ctl stop sidekiq

# ---------- 還原 ----------
echo ">>> gitlab-backup restore（需要一段時間）"
docker compose exec -T gitlab gitlab-backup restore "BACKUP=${BACKUP_ID}" force=yes

# ---------- 重啟 + 檢查 ----------
echo ">>> reconfigure + restart"
docker compose exec -T gitlab gitlab-ctl reconfigure
docker compose restart gitlab

echo ">>> 完成後建議跑健檢："
echo "    docker compose exec gitlab gitlab-rake gitlab:check SANITIZE=true"
echo "    docker compose exec gitlab gitlab-rake gitlab:doctor:secrets"
