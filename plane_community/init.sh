#!/usr/bin/env bash
set -euo pipefail

############################################
# Plane 社群版初始化腳本（自動啟動）
# - 所有資料落地 /data/plane-ce/data
# - 自動修改 docker-compose.yaml
# - 最後自動 docker compose up -d
############################################

BASE_DIR="/data/plane-ce"
APP_DIR="${BASE_DIR}/plane-app"
DATA_DIR="${BASE_DIR}/data"
SETUP_SH="${BASE_DIR}/setup.sh"
COMPOSE_FILE="${APP_DIR}/docker-compose.yaml"

echo "==> [1/8] 建立基本目錄"
sudo mkdir -p "${BASE_DIR}"
sudo mkdir -p "${DATA_DIR}"

echo "==> [2/8] 下載官方 setup.sh"
sudo curl -fsSL -o "${SETUP_SH}" https://github.com/makeplane/plane/releases/latest/download/setup.sh
sudo chmod +x "${SETUP_SH}"

echo "==> [3/8] 檢查 python3 與 PyYAML"
if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ 找不到 python3，請先安裝"
  exit 1
fi

if ! python3 - <<'PY' >/dev/null 2>&1; then
import yaml
PY
then
  echo "==> 未安裝 PyYAML，嘗試自動安裝（dnf）"
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf -y install python3-pyyaml
  else
    echo "❌ 系統非 dnf，請手動安裝 PyYAML"
    exit 1
  fi
fi

echo "==> [4/8] 執行官方 setup.sh（選項 1）"
cd "${BASE_DIR}"
sudo "${SETUP_SH}" 1

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "❌ 找不到 ${COMPOSE_FILE}"
  exit 1
fi

echo "==> [5/8] 建立資料與 logs 目錄"
sudo mkdir -p \
  "${DATA_DIR}/pgdata" \
  "${DATA_DIR}/redisdata" \
  "${DATA_DIR}/rabbitmq_data" \
  "${DATA_DIR}/uploads" \
  "${DATA_DIR}/proxy/config" \
  "${DATA_DIR}/proxy/data" \
  "${DATA_DIR}/logs/api" \
  "${DATA_DIR}/logs/worker" \
  "${DATA_DIR}/logs/beat-worker" \
  "${DATA_DIR}/logs/migrator"

echo "==> [6/8] 修改 docker-compose.yaml（改成 bind mount）"
BACKUP_FILE="${COMPOSE_FILE}.bak.$(date +%F_%H%M%S)"
sudo cp -a "${COMPOSE_FILE}" "${BACKUP_FILE}"
echo "    已備份：${BACKUP_FILE}"

sudo python3 - <<'PY'
import yaml

data_dir = "/data/plane-ce/data"
compose_path = "/data/plane-ce/plane-app/docker-compose.yaml"

with open(compose_path, "r", encoding="utf-8") as f:
    doc = yaml.safe_load(f)

services = doc.get("services", {})

def 設定(名稱, 掛載):
    if 名稱 in services:
        services[名稱]["volumes"] = 掛載

設定("api",         [f"{data_dir}/logs/api:/code/plane/logs"])
設定("worker",      [f"{data_dir}/logs/worker:/code/plane/logs"])
設定("beat-worker", [f"{data_dir}/logs/beat-worker:/code/plane/logs"])
設定("migrator",    [f"{data_dir}/logs/migrator:/code/plane/logs"])

設定("plane-db",    [f"{data_dir}/pgdata:/var/lib/postgresql/data"])
設定("plane-redis", [f"{data_dir}/redisdata:/data"])
設定("plane-mq",    [f"{data_dir}/rabbitmq_data:/var/lib/rabbitmq"])
設定("plane-minio", [f"{data_dir}/uploads:/export"])
設定("proxy",       [f"{data_dir}/proxy/config:/config",
                      f"{data_dir}/proxy/data:/data"])

if "volumes" in doc:
    del doc["volumes"]

with open(compose_path, "w", encoding="utf-8") as f:
    yaml.safe_dump(doc, f, sort_keys=False, allow_unicode=True)

print("✔ docker-compose.yaml 已更新")
PY

echo "==> [7/8] 自動啟動 Plane（docker compose up -d）"
cd "${APP_DIR}"
sudo docker compose --env-file plane.env up -d

echo "==> [8/8] 啟動完成，顯示服務狀態"
sudo docker compose ps

echo ""
echo "🎉 Plane 社群版已完成初始化並啟動"
echo "📂 資料位置：${DATA_DIR}"
echo "🌐 請用瀏覽器開啟 WEB_URL（plane.env 中設定）"
