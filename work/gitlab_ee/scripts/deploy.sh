#!/usr/bin/env bash
# 部署（首次啟動）GitLab EE on Docker
# 用法：./scripts/deploy.sh
# 若使用者不在 docker 群組，請整支用 sudo 跑：sudo ./scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJ_DIR}"

# ---------- 前置檢查 ----------
if [[ ! -f .env ]]; then
  echo "錯誤：找不到 .env，請先：cp .env.example .env 並修改參數" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .env

if ! docker compose version >/dev/null 2>&1; then
  echo "錯誤：docker compose 不可用（沒裝 compose plugin，或需要 sudo）" >&2
  exit 1
fi

# ---------- 建立持久化目錄 ----------
echo ">>> 建立資料目錄 ${GITLAB_HOME}/{config,logs,data}"
mkdir -p "${GITLAB_HOME}/config" "${GITLAB_HOME}/logs" "${GITLAB_HOME}/data"

# ---------- 啟動 ----------
echo ">>> 拉取映像 gitlab/gitlab-ee:${GITLAB_VERSION}"
docker compose pull

echo ">>> 啟動容器（首次初始化約 5-10 分鐘）"
docker compose up -d

# ---------- 等待 healthy ----------
CONTAINER="${GITLAB_CONTAINER_NAME:-gitlab-ee}"
echo ">>> 等待容器 healthy（每 15 秒檢查一次，最多等 15 分鐘）"
for i in $(seq 1 60); do
  STATUS="$(docker inspect --format '{{.State.Health.Status}}' "${CONTAINER}" 2>/dev/null || echo starting)"
  if [[ "${STATUS}" == "healthy" ]]; then
    echo ">>> GitLab 已就緒：${EXTERNAL_URL}"
    break
  fi
  echo "    [${i}/60] 狀態：${STATUS}"
  sleep 15
done

if [[ "${STATUS:-}" != "healthy" ]]; then
  echo "警告：等待逾時，請自行檢查：docker compose logs -f gitlab" >&2
  exit 1
fi

# ---------- 印出初始 root 密碼 ----------
if [[ -z "${GITLAB_ROOT_PASSWORD:-}" ]]; then
  echo ">>> 初始 root 密碼（此檔案 24 小時後自動刪除，請立即更改密碼）："
  docker compose exec gitlab grep 'Password:' /etc/gitlab/initial_root_password || \
    echo "    （檔案不存在 —— 可能不是首次初始化，或已超過 24 小時）"
else
  echo ">>> root 密碼為 .env 中設定的 GITLAB_ROOT_PASSWORD"
fi

echo ">>> 完成。登入帳號：root"
