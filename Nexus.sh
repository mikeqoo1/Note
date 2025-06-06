#!/bin/bash

set -e

# === 使用者可修改區 ===
BIND_IP="192.168.199.235"     # ⭐ 請改成你希望綁定的 IP
USE_PODMAN=false             # true=Podman, false=Docker
PORT=9091
MEM_LIMIT="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g"

# === 自動生成區 ===
ENGINE=$(command -v docker)
$USE_PODMAN && ENGINE=$(command -v podman)

NEXUS_DIR="$HOME/nexus-deploy"
DATA_DIR="$NEXUS_DIR/nexus-data"
COMPOSE_FILE="$NEXUS_DIR/docker-compose.yml"

echo "📁 建立部署資料夾: $NEXUS_DIR"
mkdir -p "$DATA_DIR"
chmod -R 777 "$DATA_DIR"

echo "📝 產生 docker-compose.yml 綁定 IP $BIND_IP"
cat > "$COMPOSE_FILE" <<EOF
version: '3.8'

services:
  nexus:
    image: sonatype/nexus3
    container_name: nexus
    ports:
      - "${BIND_IP}:${PORT}:8081"
    volumes:
      - ./nexus-data:/nexus-data
    environment:
      - INSTALL4J_ADD_VM_PARAMS=${MEM_LIMIT}
    restart: unless-stopped
EOF

cd "$NEXUS_DIR"
echo "🚀 啟動 Nexus ..."
$ENGINE compose up -d

echo "⏳ 等待 Nexus 啟動中..."

# 等待 Nexus 回應 HTTP 200
for i in {1..30}; do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$BIND_IP:$PORT || true)
  if [ "$STATUS_CODE" = "200" ]; then
    echo "✅ Nexus 已啟動！"
    break
  else
    sleep 5
    echo "… 等待中 ($i)"
  fi
done

echo "🔑 初始密碼："
$ENGINE exec nexus cat /nexus-data/admin.password || echo "❌ 無法讀取密碼，請稍後再試。"

echo "🌐 開啟瀏覽器： http://${BIND_IP}:${PORT}"