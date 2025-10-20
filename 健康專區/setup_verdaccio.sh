#!/bin/bash
# ==========================================================
# Verdaccio Docker Installation Script
# Author: 林奎翰
# Purpose: Setup/Update private npm registry (Verdaccio)
# ==========================================================

set -e

# ---------- 基本設定 ----------
VERDACCIO_PORT=4873
VERDACCIO_DIR="/opt/verdaccio"
HTPASSWD_FILE="${VERDACCIO_DIR}/storage/htpasswd"
CONTAINER_NAME="verdaccio"

# ---------- 確認 Docker Compose ----------
if ! command -v docker &>/dev/null; then
  echo "❌ 未找到 Docker，請先安裝 Docker 後再執行。"
  exit 1
fi
if ! docker compose version &>/dev/null; then
  echo "⚙️ 未偵測到 docker compose，嘗試啟用 plugin..."
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) \
    -o $DOCKER_CONFIG/cli-plugins/docker-compose
  chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
  echo "✅ docker compose 已安裝於 $DOCKER_CONFIG/cli-plugins/docker-compose"
fi

# ---------- 建立目錄結構 ----------
echo "[+] 建立目錄: ${VERDACCIO_DIR}"
mkdir -p ${VERDACCIO_DIR}/{storage,conf,plugins}

# ---------- 建立 config.yaml ----------
# 若你之前有 config.yml，就幫你自動搬到 config.yaml
if [ -f "${VERDACCIO_DIR}/conf/config.yml" ] && [ ! -f "${VERDACCIO_DIR}/conf/config.yaml" ]; then
  echo "[*] 偵測到 conf/config.yml，改名為 conf/config.yaml"
  mv "${VERDACCIO_DIR}/conf/config.yml" "${VERDACCIO_DIR}/conf/config.yaml"
fi

if [ ! -f "${VERDACCIO_DIR}/conf/config.yaml" ]; then
cat > ${VERDACCIO_DIR}/conf/config.yaml <<'EOF'
storage: /verdaccio/storage
plugins: /verdaccio/plugins

web:
  title: 私有 NPM 套件庫 (Verdaccio)

auth:
  htpasswd:
    file: /verdaccio/storage/htpasswd
    max_users: 1000

uplinks:
  npmjs:
    url: https://registry.npmjs.org/
    strict_ssl: false
    cache: false
    ignore_upstream_failure: true

packages:
  "@*/*":
    access: $all
    publish: $authenticated
    unpublish: $authenticated
    proxy: npmjs

  "**":
    access: $all
    publish: $authenticated
    unpublish: $authenticated
    proxy: npmjs

middlewares:
  audit:
    enabled: true

logs:
  - { type: stdout, format: pretty, level: http }
EOF
fi

# 確保權限正確
chmod 644 "${VERDACCIO_DIR}/conf/config.yaml"

# ---------- 建立 docker-compose.yml（移除 version 欄位避免警告） ----------
cat > ${VERDACCIO_DIR}/docker-compose.yml <<EOF
services:
  verdaccio:
    image: verdaccio/verdaccio:6
    container_name: ${CONTAINER_NAME}
    ports:
      - "${VERDACCIO_PORT}:4873"
    volumes:
      - ${VERDACCIO_DIR}/storage:/verdaccio/storage:Z
      - ${VERDACCIO_DIR}/conf:/verdaccio/conf:Z
      - ${VERDACCIO_DIR}/plugins:/verdaccio/plugins:Z
    restart: unless-stopped
EOF

# ---------- 拉取最新 images ----------
echo "[+] 拉取 Verdaccio 最新版本..."
cd ${VERDACCIO_DIR}
docker compose pull verdaccio

# ---------- 啟動或重啟容器 ----------
if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
  echo "[*] 已存在容器，執行更新重啟..."
  docker compose down
fi
docker compose up -d

# ---------- 建立預設使用者（用 httpd:alpine 產生 htpasswd 檔） ----------
if [ ! -f "${HTPASSWD_FILE}" ]; then
  echo "[+] 建立預設使用者..."
  docker run --rm \
    -v ${VERDACCIO_DIR}/storage:/data \
    httpd:2.4-alpine \
    sh -c 'htpasswd -Bbn admin Aa123456 > /data/htpasswd'
  echo "✅ 預設帳號：admin / 密碼：Aa123456"
else
  echo "ℹ️ 已存在 htpasswd，略過建立。"
fi

# ---------- 權限校正（確保容器可寫 storage/htpasswd） ----------
# 自動偵測容器內的執行 UID（大多是 10001）
CONTAINER_UID=$(docker exec ${CONTAINER_NAME} sh -c 'id -u' 2>/dev/null || echo 10001)
CONTAINER_GID=$(docker exec ${CONTAINER_NAME} sh -c 'id -g' 2>/dev/null || echo ${CONTAINER_UID})

echo "[+] 調整 storage/htpasswd 權限給 UID:${CONTAINER_UID} GID:${CONTAINER_GID}"
chown -R ${CONTAINER_UID}:${CONTAINER_GID} "${VERDACCIO_DIR}/storage"
find "${VERDACCIO_DIR}/storage" -type d -exec chmod 775 {} \;
[ -f "${HTPASSWD_FILE}" ] && chmod 664 "${HTPASSWD_FILE}"

# 若為 SELinux Enforcing，建議把 compose 的三個 volume 都加 :Z
# 或在這裡動態套用標籤（無害）
if command -v getenforce &>/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
  echo "[*] SELinux Enforcing：套用容器檔案型態標籤"
  chcon -R -t container_file_t "${VERDACCIO_DIR}/storage" "${VERDACCIO_DIR}/conf" "${VERDACCIO_DIR}/plugins" || true
fi

# ---------- 顯示結果 ----------
echo "=========================================================="
echo " Verdaccio 啟動完成！"
echo " 位置：http://192.168.199.235:${VERDACCIO_PORT}"
echo " NPM 登入指令："
echo "   npm adduser --registry http://192.168.199.235:${VERDACCIO_PORT}"
echo " 更新流程："
echo "   sudo ./setup_verdaccio.sh   # 自動拉取新 image 並重啟"
echo "=========================================================="
