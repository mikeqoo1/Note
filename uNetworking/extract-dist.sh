#!/bin/bash

set -e

CONTAINER_NAME=uws-extract-$(date +%s)

# 🏗️ 啟動容器但不自動刪除
docker create --name "$CONTAINER_NAME" uws-http3

# 📦 從容器拷貝 dist 目錄到本地
docker cp "$CONTAINER_NAME":/opt/uWebSockets.js/dist ./dist

# 🧹 刪除暫時容器
docker rm "$CONTAINER_NAME"

echo "✅ dist 產物已匯出到本機 ./dist 目錄"
