#!/bin/bash
set -euo pipefail

# === 使用者可修改區 ===
BIND_IP="192.168.199.235"     # ⭐ 請改成你希望綁定的 IP（也可用 0.0.0.0 綁所有 IP）
USE_PODMAN=false              # true=Podman, false=Docker
PORT=9091
MEM_LIMIT="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g"
IMAGE="sonatype/nexus3:latest"

# === 自動生成區 ===
ENGINE=$(command -v docker || true)
$USE_PODMAN && ENGINE=$(command -v podman || true)
if [ -z "${ENGINE}" ]; then
  echo "❌ 找不到 docker 或 podman 執行檔"
  exit 1
fi

NEXUS_DIR="$HOME/nexus-deploy"
DATA_DIR="$NEXUS_DIR/nexus-data"
COMPOSE_FILE="$NEXUS_DIR/docker-compose.yml"

echo "📁 建立部署資料夾: $NEXUS_DIR"
mkdir -p "$DATA_DIR"
chmod -R 777 "$DATA_DIR"  # 如有 SELinux 可改為 :Z 或調整擁有者 (id 200:200)

echo "📝 產生 docker-compose.yml 綁定 IP $BIND_IP"
cat > "$COMPOSE_FILE" <<EOF
version: '3.8'

services:
  nexus:
    image: ${IMAGE}
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

# 取得目前本機 image ID（可能第一次沒抓過 → 回傳 "none"）
get_image_id() {
  ${ENGINE} image inspect -f '{{.Id}}' "${IMAGE}" 2>/dev/null || echo "none"
}

echo "🔎 檢查遠端是否有新版映像檔..."
BEFORE_ID="$(get_image_id || true)"

echo "⬇️ 拉取最新映像檔：${IMAGE}"
# 用 pull 更精準（也可改成: $ENGINE compose pull）
${ENGINE} pull "${IMAGE}" >/dev/null

AFTER_ID="$(get_image_id || true)"

if [ "${BEFORE_ID}" != "${AFTER_ID}" ] || [ "${BEFORE_ID}" = "none" ]; then
  echo "🆕 偵測到映像檔更新（${BEFORE_ID} → ${AFTER_ID}），重建容器..."
  ${ENGINE} compose up -d --force-recreate
else
  echo "✅ 映像檔已是最新（${AFTER_ID}），不重建，確保服務啟動即可。"
  ${ENGINE} compose up -d
fi

echo "⏳ 等待 Nexus 啟動中（最多約 30 次，每次 5 秒）..."
for i in {1..30}; do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${BIND_IP}:${PORT}" || true)
  if [ "$STATUS_CODE" = "200" ]; then
    echo "✅ Nexus 已啟動！"
    break
  else
    sleep 5
    echo "… 等待中 ($i)"
  fi
done

echo "🔑 初始密碼（若是第一次啟動才會有）："
${ENGINE} exec nexus sh -lc 'cat /nexus-data/admin.password' || echo "ℹ️ 若讀不到代表已初始化過或尚未產生，稍後再試。"

echo "🌐 開啟瀏覽器： http://${BIND_IP}:${PORT}"
