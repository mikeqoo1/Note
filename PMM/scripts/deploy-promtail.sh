#!/bin/bash
#
# deploy-promtail.sh — 在 DB 主機上部署 Promtail
# 用途：收集本機 DB 容器的 audit log，推送到 Loki
#
# 執行方式：
#   sudo bash deploy-promtail.sh [LOKI_URL]
#
# 範例：
#   sudo bash deploy-promtail.sh http://192.168.199.234:3100
#

set -euo pipefail

PROMTAIL_VERSION="3.4.2"
PROMTAIL_CONTAINER="promtail"
PROMTAIL_CONFIG_DIR="/data/promtail"
PMM_NETWORK="pmm-net"

LOKI_URL="${1:-}"
NODE_NAME=$(hostname -s)

echo "========================================="
echo " 部署 Promtail — Audit Log 收集"
echo " 主機: ${NODE_NAME}"
echo "========================================="

# ---- 取得 Loki URL ----
if [ -z "${LOKI_URL}" ]; then
    read -rp "請輸入 Loki URL (例: http://192.168.199.234:3100): " LOKI_URL
fi

if [ -z "${LOKI_URL}" ]; then
    echo "❌ 必須提供 Loki URL"
    exit 1
fi

echo "Loki URL: ${LOKI_URL}"

# ---- 檢查 pmm-net ----
if ! sudo docker network ls --format '{{.Name}}' | grep -q "^${PMM_NETWORK}$"; then
    echo "建立 Docker 網路 ${PMM_NETWORK}..."
    sudo docker network create ${PMM_NETWORK}
fi

# ---- 偵測本機 DB 容器 ----
echo ""
echo "偵測本機 DB 容器..."

MARIADB_CONTAINERS=$(sudo docker ps --format '{{.Names}}' | grep -iE 'maria|mysql' || true)
POSTGRES_CONTAINERS=$(sudo docker ps --format '{{.Names}}' | grep -iE 'postgres|pg' || true)
MSSQL_CONTAINERS=$(sudo docker ps --format '{{.Names}}' | grep -iE 'mssql|sqlserver' || true)

echo "  MariaDB/MySQL: ${MARIADB_CONTAINERS:-無}"
echo "  PostgreSQL:    ${POSTGRES_CONTAINERS:-無}"
echo "  MSSQL:         ${MSSQL_CONTAINERS:-無}"

# ---- 建立 Promtail 設定 ----
sudo mkdir -p ${PROMTAIL_CONFIG_DIR}

# 建立 scrape_configs 區段
SCRAPE_CONFIGS=""

# --- MariaDB audit log ---
for CONTAINER in ${MARIADB_CONTAINERS}; do
    # 取得容器的 log path（預設 MariaDB Docker log 位置）
    CONTAINER_ID=$(sudo docker inspect --format '{{.Id}}' ${CONTAINER})
    cat << MEOF >> /tmp/promtail_scrape.yaml
  - job_name: mariadb-audit-${CONTAINER}
    static_configs:
      - targets: [localhost]
        labels:
          job: db-audit
          db_type: mariadb
          container: ${CONTAINER}
          node: ${NODE_NAME}
          __path__: /var/lib/docker/containers/${CONTAINER_ID}/${CONTAINER_ID}-json.log
    pipeline_stages:
      - docker: {}
      - match:
          selector: '{container="${CONTAINER}"}'
          stages:
            - regex:
                expression: '.*(?P<audit_line>\d{8}\s+\d+:\d+:\d+,.*)'
            - output:
                source: audit_line
MEOF
done

# --- PostgreSQL pgaudit ---
for CONTAINER in ${POSTGRES_CONTAINERS}; do
    CONTAINER_ID=$(sudo docker inspect --format '{{.Id}}' ${CONTAINER})
    cat << PEOF >> /tmp/promtail_scrape.yaml
  - job_name: postgres-audit-${CONTAINER}
    static_configs:
      - targets: [localhost]
        labels:
          job: db-audit
          db_type: postgresql
          container: ${CONTAINER}
          node: ${NODE_NAME}
          __path__: /var/lib/docker/containers/${CONTAINER_ID}/${CONTAINER_ID}-json.log
    pipeline_stages:
      - docker: {}
PEOF
done

# --- MSSQL audit (透過 Docker logs) ---
for CONTAINER in ${MSSQL_CONTAINERS}; do
    CONTAINER_ID=$(sudo docker inspect --format '{{.Id}}' ${CONTAINER})
    cat << SEOF >> /tmp/promtail_scrape.yaml
  - job_name: mssql-audit-${CONTAINER}
    static_configs:
      - targets: [localhost]
        labels:
          job: db-audit
          db_type: mssql
          container: ${CONTAINER}
          node: ${NODE_NAME}
          __path__: /var/lib/docker/containers/${CONTAINER_ID}/${CONTAINER_ID}-json.log
    pipeline_stages:
      - docker: {}
SEOF
done

# 如果沒有偵測到任何容器，加一個空的 scrape config
if [ ! -f /tmp/promtail_scrape.yaml ]; then
    cat << NEOF > /tmp/promtail_scrape.yaml
  - job_name: placeholder
    static_configs:
      - targets: [localhost]
        labels:
          job: db-audit
          node: ${NODE_NAME}
          __path__: /var/log/db-audit-placeholder.log
NEOF
fi

# ---- 產生完整 Promtail config ----
echo "產生 Promtail 設定檔..."

sudo tee ${PROMTAIL_CONFIG_DIR}/promtail-config.yaml > /dev/null << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: ${LOKI_URL}/loki/api/v1/push

scrape_configs:
EOF

sudo cat /tmp/promtail_scrape.yaml >> ${PROMTAIL_CONFIG_DIR}/promtail-config.yaml
rm -f /tmp/promtail_scrape.yaml

# ---- MSSQL Audit 文字轉換（如果有 MSSQL 容器）----
if [ -n "${MSSQL_CONTAINERS}" ]; then
    echo ""
    echo "偵測到 MSSQL 容器，建立 audit log 轉換腳本..."
    sudo tee ${PROMTAIL_CONFIG_DIR}/convert-mssql-audit.sh > /dev/null << 'SCRIPT'
#!/bin/bash
# convert-mssql-audit.sh
# 將 MSSQL binary audit file (.sqlaudit) 轉換為文字
# 需要 sqlcmd 或 mssql-tools
#
# MSSQL Server Audit 使用二進位 .sqlaudit 格式
# 可透過 sys.fn_get_audit_file() 讀取
#
# 用法: 設定為 cron job，定期匯出 audit log 到文字檔
#       由 Promtail 收集送到 Loki

MSSQL_CONTAINER="${1:-demo-mssql}"
SA_PASSWORD="${2:-YourStrong!Passw0rd}"
OUTPUT_DIR="/var/log/mssql-audit"

mkdir -p ${OUTPUT_DIR}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/audit_${TIMESTAMP}.log"

# 透過 sqlcmd 查詢 audit records
sudo docker exec ${MSSQL_CONTAINER} /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "${SA_PASSWORD}" -C \
    -Q "SET NOCOUNT ON;
SELECT
    CONVERT(VARCHAR(23), event_time, 121) AS event_time,
    action_id,
    succeeded,
    session_server_principal_name AS [user],
    database_name,
    object_name,
    statement
FROM sys.fn_get_audit_file('/var/opt/mssql/audit/*.sqlaudit', DEFAULT, DEFAULT)
WHERE event_time > DATEADD(MINUTE, -5, GETUTCDATE())
ORDER BY event_time DESC;" \
    -s"|" -W -h -1 2>/dev/null >> ${OUTPUT_FILE}

if [ -s "${OUTPUT_FILE}" ]; then
    echo "$(date): 匯出 $(wc -l < ${OUTPUT_FILE}) 筆 audit records 到 ${OUTPUT_FILE}"
else
    rm -f ${OUTPUT_FILE}
fi

# 清理 7 天前的舊檔
find ${OUTPUT_DIR} -name "audit_*.log" -mtime +7 -delete 2>/dev/null
SCRIPT
    sudo chmod +x ${PROMTAIL_CONFIG_DIR}/convert-mssql-audit.sh

    echo "⚠️  MSSQL Audit 注意事項："
    echo "   1. 需先在 MSSQL 中啟用 Server Audit"
    echo "   2. 設定 cron job 定期執行轉換腳本："
    echo "      */5 * * * * ${PROMTAIL_CONFIG_DIR}/convert-mssql-audit.sh demo-mssql 'YourPassword'"
    echo "   3. 並在 promtail-config.yaml 中加入 /var/log/mssql-audit/ 路徑"
fi

# ---- 停止舊容器 ----
if sudo docker ps -a --format '{{.Names}}' | grep -q "^${PROMTAIL_CONTAINER}$"; then
    echo ""
    echo "移除舊的 ${PROMTAIL_CONTAINER} 容器..."
    sudo docker rm -f ${PROMTAIL_CONTAINER}
fi

# ---- 啟動 Promtail ----
echo ""
echo "啟動 Promtail 容器..."
sudo docker run -d \
    --name ${PROMTAIL_CONTAINER} \
    --network ${PMM_NETWORK} \
    --restart unless-stopped \
    -v ${PROMTAIL_CONFIG_DIR}/promtail-config.yaml:/etc/promtail/config.yml:ro \
    -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
    -v /var/log:/var/log:ro \
    grafana/promtail:${PROMTAIL_VERSION} \
    -config.file=/etc/promtail/config.yml

echo "等待 Promtail 啟動..."
sleep 3

# ---- 健康檢查 ----
if sudo docker logs ${PROMTAIL_CONTAINER} 2>&1 | tail -3 | grep -qi "error"; then
    echo "⚠️  Promtail 可能有錯誤："
    sudo docker logs ${PROMTAIL_CONTAINER} --tail 5
else
    echo "✅ Promtail 已啟動"
fi

echo ""
echo "========================================="
echo " Promtail 部署完成"
echo "========================================="
echo ""
echo "主機: ${NODE_NAME}"
echo "Loki: ${LOKI_URL}"
echo "收集的容器:"
[ -n "${MARIADB_CONTAINERS}" ] && echo "  MariaDB: ${MARIADB_CONTAINERS}"
[ -n "${POSTGRES_CONTAINERS}" ] && echo "  PostgreSQL: ${POSTGRES_CONTAINERS}"
[ -n "${MSSQL_CONTAINERS}" ] && echo "  MSSQL: ${MSSQL_CONTAINERS}"
echo ""
echo "驗證方式："
echo "  1. 檢查 Promtail targets: curl http://localhost:9080/targets"
echo "  2. 在 PMM Grafana → Explore → 選擇 Loki datasource"
echo "     查詢: {job=\"db-audit\", node=\"${NODE_NAME}\"}"
