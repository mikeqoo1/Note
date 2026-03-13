#!/usr/bin/env bash
set -euo pipefail

# =========================
# 基本設定
# =========================
PMM_CLIENT_DATA_DIR="${PMM_CLIENT_DATA_DIR:-/data/pmm-client}"
CONTAINER_NAME="${CONTAINER_NAME:-pmm-client}"
IMAGE="${IMAGE:-percona/pmm-client:3}"

# 遠端 PMM Server
PMM_SERVER_ADDR="${PMM_SERVER_ADDR:-192.168.199.234:18443}"
PMM_USER="${PMM_USER:-admin}"
PMM_PASS="${PMM_PASS:-Aa123456}"
PMM_INSECURE_TLS="${PMM_INSECURE_TLS:-1}"

# pmm-agent listen port（預設 7777，若被佔用請改）
PMM_AGENT_LISTEN_PORT="${PMM_AGENT_LISTEN_PORT:-7777}"

NODE_NAME="${NODE_NAME:-$(hostname -s)}"
CONFIG_FILE="/usr/local/percona/pmm/config/pmm-agent.yaml"

echo "==> PMM Client bootstrap (container, host network)"
echo "==> Node name    : ${NODE_NAME}"
echo "==> PMM Server   : ${PMM_SERVER_ADDR}"
echo "==> Agent Port   : ${PMM_AGENT_LISTEN_PORT}"
echo "==> Data dir     : ${PMM_CLIENT_DATA_DIR}"
echo

# =========================
# 檢查 PMM Server 是否可達
# =========================
echo "==> 檢查 PMM Server 連線 ..."
if curl -kso /dev/null --connect-timeout 5 "https://${PMM_SERVER_ADDR}"; then
  echo "==> PMM Server 可達 ✓"
else
  echo "==> [ERROR] 無法連線到 https://${PMM_SERVER_ADDR}"
  echo "    請確認網路 / 防火牆 / PMM Server 是否運行中"
  exit 1
fi
echo

# =========================
# 檢查 agent port 是否被佔用
# =========================
echo "==> 檢查 port ${PMM_AGENT_LISTEN_PORT} ..."
if ss -tlnp 2>/dev/null | grep -q ":${PMM_AGENT_LISTEN_PORT} "; then
  echo "==> [ERROR] Port ${PMM_AGENT_LISTEN_PORT} 已被佔用！"
  echo "    佔用程式："
  ss -tlnp | grep ":${PMM_AGENT_LISTEN_PORT} "
  echo
  echo "    請改用其他 port："
  echo "    PMM_AGENT_LISTEN_PORT=17777 sudo -E bash $0"
  exit 1
fi
echo "==> Port ${PMM_AGENT_LISTEN_PORT} 可用 ✓"
echo

# =========================
# SELinux（如有）: volume 加 :Z
# =========================
VOLUME_OPT=""
if command -v getenforce >/dev/null 2>&1; then
  if [[ "$(getenforce)" == "Enforcing" ]]; then
    VOLUME_OPT=":Z"
    echo "==> SELinux Enforcing detected, using :Z"
  fi
fi

# =========================
# Pull image
# =========================
echo "==> Pull image: ${IMAGE}"
sudo docker pull "${IMAGE}"
echo

# =========================
# 清除舊容器
# =========================
echo "==> 清除舊容器 ..."
sudo docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# =========================
# 準備資料目錄
# =========================
echo "==> 準備資料目錄 ..."
sudo mkdir -p "${PMM_CLIENT_DATA_DIR}"/{config,tmp}

# 修正權限（取得容器內 UID/GID）
read -r PMM_UID PMM_GID < <(
  sudo docker run --rm --entrypoint id "${IMAGE}" -u 2>/dev/null | tr -d '\r'
  echo -n " "
  sudo docker run --rm --entrypoint id "${IMAGE}" -g 2>/dev/null | tr -d '\r'
) || true

# 如果偵測不到就用預設值
PMM_UID="${PMM_UID:-1002}"
PMM_GID="${PMM_GID:-1002}"
echo "==> Container UID:GID = ${PMM_UID}:${PMM_GID}"
sudo chown -R "${PMM_UID}:${PMM_GID}" "${PMM_CLIENT_DATA_DIR}"
echo

# =========================
# [1/2] Setup（一次性，產生 config）
# 繞過 entrypoint，直接呼叫 pmm-agent setup
# =========================
echo "==> [1/2] 執行 pmm-agent setup ..."

INSECURE_FLAG=""
if [[ "${PMM_INSECURE_TLS}" == "1" ]]; then
  INSECURE_FLAG="--server-insecure-tls"
fi

sudo docker run --rm \
  --name "${CONTAINER_NAME}-setup" \
  --network host \
  --entrypoint pmm-agent \
  -v "${PMM_CLIENT_DATA_DIR}/config:/usr/local/percona/pmm/config${VOLUME_OPT}" \
  -v "${PMM_CLIENT_DATA_DIR}/tmp:/usr/local/percona/pmm/tmp${VOLUME_OPT}" \
  "${IMAGE}" \
  setup \
    --config-file="${CONFIG_FILE}" \
    --server-address="${PMM_SERVER_ADDR}" \
    --server-username="${PMM_USER}" \
    --server-password="${PMM_PASS}" \
    ${INSECURE_FLAG} \
    --listen-port="${PMM_AGENT_LISTEN_PORT}" \
    --force

# 驗證 config 產生
if sudo test -f "${PMM_CLIENT_DATA_DIR}/config/pmm-agent.yaml"; then
  echo "==> Config 產生成功 ✓"
else
  echo "==> [ERROR] Config 未產生，setup 失敗"
  exit 1
fi
echo

# =========================
# [2/2] Run（常駐）
# =========================
echo "==> [2/2] 啟動 pmm-client daemon ..."
sudo docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  --network host \
  --entrypoint pmm-agent \
  -v "${PMM_CLIENT_DATA_DIR}/config:/usr/local/percona/pmm/config${VOLUME_OPT}" \
  -v "${PMM_CLIENT_DATA_DIR}/tmp:/usr/local/percona/pmm/tmp${VOLUME_OPT}" \
  "${IMAGE}" \
  run --config-file="${CONFIG_FILE}"
echo

# =========================
# 等待 pmm-agent 就緒
# =========================
echo -n "==> 等待 pmm-agent 就緒 "
MAX_WAIT=30
ELAPSED=0
while ! sudo docker exec "${CONTAINER_NAME}" pmm-admin status >/dev/null 2>&1; do
  echo -n "."
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    echo
    echo "==> [WARN] 等待逾時（${MAX_WAIT}s），檢查 logs："
    sudo docker logs --tail=20 "${CONTAINER_NAME}"
    exit 1
  fi
done
echo " OK"
echo

# =========================
# Post-check
# =========================
echo "==> Container status:"
sudo docker ps --filter "name=^${CONTAINER_NAME}$" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo

echo "==> pmm-admin status:"
sudo docker exec "${CONTAINER_NAME}" pmm-admin status
echo

echo "==> DONE."
echo "    下一步：用 add-db.sh 註冊資料庫"
echo "    或手動：sudo docker exec -it ${CONTAINER_NAME} pmm-admin add mysql --help"
