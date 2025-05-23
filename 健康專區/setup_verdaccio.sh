#!/bin/bash

# ===============================================================
# Verdaccio 私有 NPM 倉庫一鍵建立腳本
# ===============================================================

set -e  # 只要有錯誤馬上停止

echo "🔵 Step 1: 建立 storage / config 目錄..."
mkdir -p ~/verdaccio/storage
mkdir -p ~/verdaccio/config

echo "🔵 Step 2: 建立空的 htpasswd 檔案..."
touch ~/verdaccio/storage/htpasswd

echo "🔵 Step 3: 設定 htpasswd 擁有者 (目前登入使用者)"
sudo chown $(id -u):$(id -g) ~/verdaccio/storage/htpasswd

echo "🔵 Step 4: 設定 storage 目錄權限 (777 開放)"
chmod -R 777 ~/verdaccio/storage

echo "🔵 Step 5: 請確認你的 config.yaml 放置位置正確：~/verdaccio/config/config.yaml"
echo "    📂 Verdaccio-config.yaml ➔ ~/verdaccio/config/config.yaml"

echo "🔵 Step 6: 請確認你的 docker-compose.yml 放置位置正確：~/verdaccio/docker-compose.yml"
echo "    📂 Verdaccio-DockerCompose.yml ➔ ~/verdaccio/docker-compose.yml"

echo "🔵 Step 7: 建立 .env 檔案 (自動帶入 UID:GID)"
cat <<EOF > ~/verdaccio/.env
UID=$(id -u)
GID=$(id -g)
EOF

echo "✅ 成功建立 .env，內容如下："
cat ~/verdaccio/.env

echo "🔵 Step 8: 啟動 Verdaccio 服務 (podman compose up -d)"
cd ~/verdaccio
podman compose -f docker-compose.yml up -d

echo "🎉 Verdaccio 私有 NPM 倉庫部署完成！"
echo ""
echo "👉 預設服務網址: http://localhost:4873/"
echo "👉 要關閉服務請執行: podman compose -f docker-compose.yml down"
