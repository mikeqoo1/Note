#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:-}"
if [[ -z "${ARCHIVE}" ]]; then
  echo "用法：$0 /path/to/plane-backup-YYYY-MM-DD.tar.gz"
  exit 1
fi
if [[ ! -f "${ARCHIVE}" ]]; then
  echo "找不到備份檔：${ARCHIVE}"
  exit 1
fi

# === 你的社群版根目錄（你已經固定）===
PLANE_ROOT="/data/plane-ce"
APP_DIR="${PLANE_ROOT}/plane-app"

# === 你的社群版資料落地位置（bind mount）===
DATA_DIR="${PLANE_ROOT}/data"
PG_DST="${DATA_DIR}/pgdata"
REDIS_DST="${DATA_DIR}/redisdata"
MINIO_DST="${DATA_DIR}/uploads"

WORKDIR="/tmp/plane_restore_$(date +%s)"
mkdir -p "${WORKDIR}"

echo "[0/10] 基本檢查"
[[ -d "${APP_DIR}" ]] || { echo "ERROR：找不到 ${APP_DIR}（社群版 plane-app 目錄）"; exit 1; }
[[ -f "${APP_DIR}/docker-compose.yaml" ]] || { echo "ERROR：找不到 ${APP_DIR}/docker-compose.yaml"; exit 1; }

echo "[1/10] 停止社群版 Plane（docker compose down）"
cd "${APP_DIR}"
if [[ -f "${APP_DIR}/plane.env" ]]; then
  sudo docker compose --env-file plane.env down
else
  sudo docker compose down
fi

echo "[2/10] 解壓縮備份到暫存：${WORKDIR}"
sudo tar -xzvf "${ARCHIVE}" -C "${WORKDIR}" >/dev/null

echo "[3/10] 找到解壓後的 data/ 目錄"
DATA_SRC=""
if [[ -d "${WORKDIR}/data" ]]; then
  DATA_SRC="${WORKDIR}/data"
else
  # 有些備份會帶上 /opt/plane/data 或更深層
  DATA_SRC="$(find "${WORKDIR}" -maxdepth 6 -type d -name data | head -n 1 || true)"
fi

if [[ -z "${DATA_SRC}" || ! -d "${DATA_SRC}" ]]; then
  echo "ERROR：找不到解壓後的 data/ 目錄"
  echo "WORKDIR 內容："
  ls -lah "${WORKDIR}" || true
  exit 1
fi
echo "使用 DATA_SRC=${DATA_SRC}"

echo "[4/10] 偵測商業版來源資料夾"

# 商業版 Postgres 常見：data/db
PG_SRC="${DATA_SRC}/db"

# Redis 常見：data/redisdata 或 data/redis
REDIS_SRC=""
if [[ -d "${DATA_SRC}/redisdata" ]]; then
  REDIS_SRC="${DATA_SRC}/redisdata"
elif [[ -d "${DATA_SRC}/redis" ]]; then
  REDIS_SRC="${DATA_SRC}/redis"
fi

# MinIO 常見：data/minio/uploads（裡面會有 .minio.sys + bucket目錄）
MINIO_SRC=""
if [[ -d "${DATA_SRC}/minio/uploads" ]]; then
  MINIO_SRC="${DATA_SRC}/minio/uploads"
elif [[ -d "${DATA_SRC}/minio" ]]; then
  MINIO_SRC="${DATA_SRC}/minio"
fi

# 檢查
[[ -d "${PG_SRC}" ]] || { echo "ERROR：找不到 Postgres 來源資料：${PG_SRC}"; exit 1; }
[[ -n "${REDIS_SRC}" && -d "${REDIS_SRC}" ]] || { echo "ERROR：找不到 Redis 來源資料（redisdata/ 或 redis/）"; exit 1; }
[[ -n "${MINIO_SRC}" && -d "${MINIO_SRC}" ]] || { echo "ERROR：找不到 MinIO 來源資料（minio/uploads 或 minio/）"; exit 1; }

echo "PG_SRC=${PG_SRC}"
echo "REDIS_SRC=${REDIS_SRC}"
echo "MINIO_SRC=${MINIO_SRC}"

echo "[5/10] 建立社群版目的資料夾"
sudo mkdir -p "${PG_DST}" "${REDIS_DST}" "${MINIO_DST}"

echo "[6/10] 還原 Postgres → ${PG_DST}"
# 注意：--delete 會讓目的地與備份一致（通常是你要的）
sudo rsync -aHAX --delete --info=progress2 "${PG_SRC}/" "${PG_DST}/"

echo "[7/10] 還原 Redis/Valkey → ${REDIS_DST}"
sudo rsync -aHAX --delete --info=progress2 "${REDIS_SRC}/" "${REDIS_DST}/"

echo "[8/10] 還原 MinIO (/export) → ${MINIO_DST}"
# 重要：MINIO_SRC 內最好直接包含 .minio.sys/ + uploads(bucket) 等資料夾
sudo rsync -aHAX --delete --info=progress2 "${MINIO_SRC}/" "${MINIO_DST}/"

echo "[9/10] 修正檔案擁有者（避免容器無法寫入）"
# Postgres alpine 預設常用 uid/gid: 70:70
# Valkey/Redis 常見 999:999（不一定完全相同，但大多可用；不行再改成用容器內 chown）
# MinIO 常見 1000:1000
sudo chown -R 70:70 "${PG_DST}" || true
sudo chown -R 999:999 "${REDIS_DST}" || true
sudo chown -R 1000:1000 "${MINIO_DST}" || true

echo "[10/10] 啟動社群版 Plane（docker compose up -d）"
cd "${APP_DIR}"
if [[ -f "${APP_DIR}/plane.env" ]]; then
  sudo docker compose --env-file plane.env up -d
else
  sudo docker compose up -d
fi

echo ""
echo "✅ 完成：商業版資料已倒入社群版 bind mount 目錄"
echo "   PG：${PG_DST}"
echo "   Redis：${REDIS_DST}"
echo "   MinIO：${MINIO_DST}"
echo ""
echo "檢查服務狀態："
sudo docker compose ps || true

echo ""
echo "（可選）快速檢查 MinIO bucket："
MINIO_CID="$(sudo docker ps --format '{{.ID}} {{.Image}} {{.Names}}' | awk '$2 ~ /minio\/minio/ {print $1; exit}')"
if [[ -n "${MINIO_CID}" ]]; then
  sudo docker exec -it "${MINIO_CID}" sh -lc \
    'mc alias set local http://127.0.0.1:9000 access-key secret-key >/dev/null 2>&1 || true; mc ls local/uploads | head -n 20' \
    || true
else
  echo "找不到 minio 容器，略過。"
fi

echo ""
echo "暫存解壓目錄保留在：${WORKDIR}"
echo "確認無誤後你可以手動刪掉：sudo rm -rf ${WORKDIR}"
