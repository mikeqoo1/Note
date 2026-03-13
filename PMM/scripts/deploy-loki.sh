#!/bin/bash
#
# deploy-loki.sh — 在 PMM Server 主機上部署 Loki
# 用途：收集各 DB 主機的 audit log，在 PMM Grafana 中查看
#
# 執行方式：在 PMM Server 主機上執行
#   sudo bash deploy-loki.sh
#

set -euo pipefail

LOKI_VERSION="3.4.2"
LOKI_CONTAINER="loki"
LOKI_PORT="3100"
LOKI_DATA_DIR="/data/loki"
LOKI_CONFIG_DIR="/data/loki/config"
PMM_NETWORK="pmm-net"
PMM_CONTAINER="pmm-server"
GRAFANA_ADMIN_PASS="${GRAFANA_ADMIN_PASS:-admin}"

echo "========================================="
echo " 部署 Loki — PMM Audit Log 收集"
echo "========================================="

# ---- 檢查是否為 PMM Server 主機 ----
if ! sudo docker ps --format '{{.Names}}' | grep -q "^${PMM_CONTAINER}$"; then
    echo "❌ 找不到 ${PMM_CONTAINER} 容器，請在 PMM Server 主機上執行此腳本"
    exit 1
fi

# ---- 檢查 pmm-net 網路 ----
if ! sudo docker network ls --format '{{.Name}}' | grep -q "^${PMM_NETWORK}$"; then
    echo "建立 Docker 網路 ${PMM_NETWORK}..."
    sudo docker network create ${PMM_NETWORK}
fi

# 確保 pmm-server 在 pmm-net 上
if ! sudo docker inspect ${PMM_CONTAINER} --format '{{json .NetworkSettings.Networks}}' | grep -q "${PMM_NETWORK}"; then
    echo "將 ${PMM_CONTAINER} 加入 ${PMM_NETWORK}..."
    sudo docker network connect ${PMM_NETWORK} ${PMM_CONTAINER}
fi

# ---- 建立目錄 ----
echo "建立 Loki 資料目錄..."
sudo mkdir -p ${LOKI_CONFIG_DIR}
sudo mkdir -p ${LOKI_DATA_DIR}/chunks
sudo mkdir -p ${LOKI_DATA_DIR}/rules
sudo mkdir -p ${LOKI_DATA_DIR}/compactor
sudo mkdir -p ${LOKI_DATA_DIR}/boltdb-shipper-active
sudo mkdir -p ${LOKI_DATA_DIR}/boltdb-shipper-cache
# Loki 容器跑在 uid 10001，需要寫入權限
sudo chown -R 10001:10001 ${LOKI_DATA_DIR}

# ---- 產生 Loki config ----
echo "產生 Loki 設定檔..."
sudo tee ${LOKI_CONFIG_DIR}/loki-config.yaml > /dev/null << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 90d
  max_query_length: 90d

compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  delete_request_store: filesystem

analytics:
  reporting_enabled: false
EOF

# ---- 停止舊容器（如果有）----
if sudo docker ps -a --format '{{.Names}}' | grep -q "^${LOKI_CONTAINER}$"; then
    echo "移除舊的 ${LOKI_CONTAINER} 容器..."
    sudo docker rm -f ${LOKI_CONTAINER}
fi

# ---- 啟動 Loki ----
echo "啟動 Loki 容器..."
sudo docker run -d \
    --name ${LOKI_CONTAINER} \
    --network ${PMM_NETWORK} \
    --restart unless-stopped \
    -p ${LOKI_PORT}:3100 \
    -v ${LOKI_CONFIG_DIR}/loki-config.yaml:/etc/loki/local-config.yaml:ro \
    -v ${LOKI_DATA_DIR}:/loki \
    grafana/loki:${LOKI_VERSION} \
    -config.file=/etc/loki/local-config.yaml

echo "等待 Loki 啟動..."
sleep 5

# ---- 健康檢查 ----
if curl -sf http://127.0.0.1:${LOKI_PORT}/ready > /dev/null 2>&1; then
    echo "✅ Loki 已啟動並就緒"
else
    echo "⚠️  Loki 尚未就緒，檢查 logs："
    sudo docker logs ${LOKI_CONTAINER} --tail 10
    echo ""
    echo "等幾秒後可再次測試: curl http://127.0.0.1:${LOKI_PORT}/ready"
fi

# ---- 在 PMM Grafana 中加入 Loki 為 datasource ----
echo ""
echo "設定 Grafana Loki Datasource..."

LOKI_INTERNAL_URL="http://${LOKI_CONTAINER}:3100"

# PMM Grafana 跑在 pmm-server 容器內，透過 127.0.0.1:18443 存取
# 試幾種常見的 Grafana API 路徑
GRAFANA_API=""
for BASE_URL in "https://127.0.0.1:18443/graph" "https://127.0.0.1:18443" "http://127.0.0.1:3000"; do
    if curl -skf -u "admin:${GRAFANA_ADMIN_PASS}" "${BASE_URL}/api/datasources" > /dev/null 2>&1; then
        GRAFANA_API="${BASE_URL}"
        break
    fi
done

if [ -z "${GRAFANA_API}" ]; then
    echo "⚠️  無法連接 Grafana API，請手動新增 Loki datasource"
    echo "   PMM Grafana → Configuration → Data Sources → Add → Loki"
    echo "   URL: ${LOKI_INTERNAL_URL}"
else
    echo "Grafana API: ${GRAFANA_API}"

    # 先檢查是否已存在
    EXISTING=$(curl -skf -u "admin:${GRAFANA_ADMIN_PASS}" \
        "${GRAFANA_API}/api/datasources/name/Loki" 2>/dev/null || true)

    if echo "${EXISTING}" | grep -q '"id"'; then
        echo "Loki datasource 已存在，跳過"
    else
        HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
            -u "admin:${GRAFANA_ADMIN_PASS}" \
            -X POST "${GRAFANA_API}/api/datasources" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"Loki\",
                \"type\": \"loki\",
                \"url\": \"${LOKI_INTERNAL_URL}\",
                \"access\": \"proxy\",
                \"isDefault\": false
            }" 2>/dev/null || echo "000")

        if [ "${HTTP_CODE}" = "200" ] || [ "${HTTP_CODE}" = "409" ]; then
            echo "✅ Loki datasource 已加入 Grafana"
        else
            echo "⚠️  Grafana datasource 設定失敗 (HTTP ${HTTP_CODE})"
            echo "   請手動在 PMM Grafana → Configuration → Data Sources 中新增 Loki"
            echo "   URL: ${LOKI_INTERNAL_URL}"
        fi
    fi
fi

echo ""
echo "========================================="
echo " Loki 部署完成"
echo "========================================="
echo ""
echo "Loki endpoint: http://$(hostname -I | awk '{print $1}'):${LOKI_PORT}"
echo "Loki 容器網路: ${PMM_NETWORK}"
echo ""
echo "下一步：在各 DB 主機上執行 deploy-promtail.sh"
echo "  sudo bash deploy-promtail.sh"
