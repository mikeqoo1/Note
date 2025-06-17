#!/bin/bash

set -e

# === 使用者可修改區 ===
BIND_IP="192.168.199.235"     # ⭐ 請改成你希望綁定的 IP
USE_PODMAN=false              # true=Podman, false=Docker
PORT=6610                    # 對外服務的 port

# === 自動生成區 ===
ENGINE=$(command -v docker)
$USE_PODMAN && ENGINE=$(command -v podman)

DEPLOY_DIR="$HOME/onedev-deploy"
DATA_DIR="$DEPLOY_DIR/onedev"
TRUST_CERT_DIR="$DATA_DIR/.trust-certs"
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"

echo "📁 建立部署資料夾: $DEPLOY_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$TRUST_CERT_DIR"
chmod -R 755 "$DATA_DIR"

echo "📝 產生 docker-compose.yml 綁定 IP $BIND_IP"
cat > "$COMPOSE_FILE" <<EOF
version: '3.8'

services:
  onedev:
    image: 1dev/server:latest
    container_name: onedev
    ports:
      - "${BIND_IP}:${PORT}:6610"
    volumes:
      - ./onedev:/opt/onedev
    restart: unless-stopped
EOF

cd "$DEPLOY_DIR"
echo "🚀 啟動 OneDev ..."
$ENGINE compose up -d

echo "⏳ 等待 OneDev 啟動中..."

# 等待 HTTP 回應 200
for i in {1..10}; do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$BIND_IP:$PORT || true)
  if [ "$STATUS_CODE" = "200" ]; then
    echo "✅ OneDev 已啟動！"
    break
  else
    sleep 5
    echo "… 等待中 ($i)"
  fi
done

echo ""
echo "📂 資料儲存目錄： $DATA_DIR"
echo "📜 憑證掛載目錄： $TRUST_CERT_DIR"
echo "🌐 請打開瀏覽器: http://${BIND_IP}:${PORT}"
echo "🔐 若您已放置自簽憑證於 onedev/.trust-certs/ 資料夾，系統已信任它們"
echo "🛠️ 首次啟動會進入初始化介面，請建立管理員帳號"
