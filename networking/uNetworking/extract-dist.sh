#!/bin/bash
set -euo pipefail

IMAGE_NAME=uws-http3                     # 你 build 的那顆 image
OUT_DIR=${1:-./uws}     # 匯出目標資料夾，可用參數覆寫

CONTAINER_NAME=uws-extract-$(date +%s)

echo "📦 建立暫時容器 $CONTAINER_NAME ..."
docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" > /dev/null

mkdir -p "$OUT_DIR"

echo "📥 複製 dist/ (含 uws.js + .node)..."
docker cp "$CONTAINER_NAME":/opt/uWebSockets.js/dist "$OUT_DIR"/dist

echo "🧹 刪除暫時容器 ..."
docker rm "$CONTAINER_NAME" > /dev/null

# 若沒有 package.json，就補一個最小版
if [ ! -f "$OUT_DIR/package.json" ]; then
  cat > "$OUT_DIR/package.json" <<'JSON'
{
  "name": "@uws",
  "version": "http3-custom-1.0.0",
  "main": "dist/uws.js",
  "os": ["linux"],
  "cpu": ["x64"]
}
JSON
fi

echo "✅ 產物已匯出到 $OUT_DIR"
echo "   之後在 Node 專案的 package.json 裡可以用："
echo "   \"@uws\": \"file:./$(basename "$OUT_DIR")\""
