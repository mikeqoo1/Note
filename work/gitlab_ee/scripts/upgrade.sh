#!/usr/bin/env bash
# 升級 GitLab EE 版本：先備份 → 改 .env 版本 → 拉新映像重建
# 用法：./scripts/upgrade.sh <新版本tag>
#   例：./scripts/upgrade.sh 19.3.0-ee.0
#
# !!! 升級不可跳版（尤其跨大版），先查官方升級路徑：
#     https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/
#     例：18.3 → 19.1 可能得先停靠 18.11 再上 19.x

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJ_DIR}"

# shellcheck disable=SC1091
source .env

if [[ $# -ne 1 ]]; then
  echo "用法：$0 <新版本tag>（例：19.3.0-ee.0）" >&2
  echo "目前版本：${GITLAB_VERSION}" >&2
  exit 1
fi
NEW_VERSION="$1"

echo ">>> ${GITLAB_VERSION} → ${NEW_VERSION}"
echo "已確認過升級路徑允許直升嗎？（跨版升級須逐站停靠）"
read -r -p "輸入 yes 繼續：" CONFIRM
[[ "${CONFIRM}" == "yes" ]] || { echo "已取消"; exit 1; }

# ---------- 升級前備份 ----------
echo ">>> [1/4] 升級前備份"
"${SCRIPT_DIR}/backup.sh"

# ---------- 確認背景遷移已跑完 ----------
echo ">>> [2/4] 檢查上一版的 background migrations 是否完成（必須為 0 才能升）"
PENDING="$(docker compose exec -T gitlab gitlab-rails runner -e production \
  'puts Gitlab::Database::BackgroundMigration::BatchedMigration.queued.count' | tr -d '[:space:]')"
if [[ "${PENDING}" != "0" ]]; then
  echo "錯誤：還有 ${PENDING} 個 background migration 未完成，等跑完再升級" >&2
  exit 1
fi

# ---------- 改版本並重建 ----------
echo ">>> [3/4] 更新 .env 版本並重建容器"
sed -i.bak-upgrade "s/^GITLAB_VERSION=.*/GITLAB_VERSION=${NEW_VERSION}/" .env
docker compose pull
docker compose up -d

# ---------- 等待 healthy ----------
CONTAINER="${GITLAB_CONTAINER_NAME:-gitlab-ee}"
echo ">>> [4/4] 等待 healthy（升級含 DB migration，最多等 20 分鐘）"
for i in $(seq 1 80); do
  STATUS="$(docker inspect --format '{{.State.Health.Status}}' "${CONTAINER}" 2>/dev/null || echo starting)"
  [[ "${STATUS}" == "healthy" ]] && { echo ">>> 升級完成：${NEW_VERSION}"; exit 0; }
  echo "    [${i}/80] 狀態：${STATUS}"
  sleep 15
done

echo "警告：等待逾時，請檢查：docker compose logs -f gitlab" >&2
echo "（若失敗要回舊版：把 .env 版本改回去 + docker compose up -d，再用備份還原）" >&2
exit 1
