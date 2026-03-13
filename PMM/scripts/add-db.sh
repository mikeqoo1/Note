#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# PMM 資料庫註冊腳本（互動式）
# 支援：MySQL/MariaDB、PostgreSQL、MSSQL
# PMM Client 以容器方式運行
# ============================================================

# ----- 預設值 -----
PMM_CLIENT_CONTAINER="${PMM_CLIENT_CONTAINER:-pmm-client}"
# 變更紀錄：從 awaragi/prometheus-mssql-exporter (Node.js/tedious) 改為
# burningalchemist/sql_exporter (Go/go-mssqldb)。
# 原因：awaragi 的 tedious driver v16+ 與 MSSQL 2022 TLS 握手不相容，
#       導致 "Connection lost - socket hang up"，不同機器 pull 到不同版本會有不同結果。
#       Go-based 的 sql_exporter 使用微軟官方 go-mssqldb driver，完全相容 MSSQL 2022。
MSSQL_EXPORTER_IMAGE="burningalchemist/sql_exporter:latest"

# ----- 顏色 -----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ----- 工具函式 -----
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
ask()   { echo -en "${CYAN}$1${NC}" >&2; }

# 讀取輸入（帶預設值）
# 所有提示輸出到 stderr，只有最終值輸出到 stdout
read_input() {
  local prompt="$1" default="${2:-}" required="${3:-}" value
  while true; do
    if [[ -n "$default" ]]; then
      echo -en "${CYAN}${prompt} [${default}]: ${NC}" >&2
    else
      echo -en "${CYAN}${prompt}: ${NC}" >&2
    fi
    read -r value
    value="${value:-$default}"
    if [[ -n "$value" ]]; then
      echo "$value"
      return
    fi
    if [[ "$required" == "required" ]]; then
      echo -e "${RED}[ERROR]${NC} 此欄位為必填，請重新輸入" >&2
    else
      echo ""
      return
    fi
  done
}

# 讀取密碼（提示輸出到 stderr）
read_password() {
  local prompt="$1" value
  echo -en "${CYAN}${prompt}: ${NC}" >&2
  read -rs value
  echo >&2
  echo "$value"
}

# 列出正在運行的 DB 容器（排除 pmm 相關）
show_running_containers() {
  {
    echo
    info "目前運行中的容器："
    sudo docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -v "pmm" || echo "  （無）"
    echo
  } >&2
}

# URL-encode 密碼（用於 sql_exporter DSN）
url_encode_password() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read(),safe=''))"
  else
    # fallback: 處理常見特殊字元
    printf '%s' "$1" | sed \
      -e 's/%/%25/g' -e 's/ /%20/g' -e 's/!/%21/g' -e 's/#/%23/g' \
      -e 's/\$/%24/g' -e 's/&/%26/g' -e "s/'/%27/g" -e 's/(/%28/g' \
      -e 's/)/%29/g' -e 's/+/%2B/g' -e 's/:/%3A/g' -e 's/;/%3B/g' \
      -e 's/=/%3D/g' -e 's/?/%3F/g' -e 's/@/%40/g'
  fi
}

# 寫入 sql_exporter 主設定檔
write_mssql_exporter_config() {
  local config_path="$1" dsn="$2"
  sudo tee "${config_path}" >/dev/null <<YAMLDOC
global:
  scrape_timeout_offset: 500ms
  min_interval: 0s
  max_connections: 3
  max_idle_connections: 3

target:
  data_source_name: '${dsn}'
  collectors:
    - mssql_standard

collector_files:
  - "/etc/sql_exporter/*.collector.yml"
YAMLDOC
}

# 寫入 MSSQL Collector 定義（Prometheus metric 對應的 SQL 查詢）
write_mssql_collector() {
  sudo tee "$1" >/dev/null <<'YAMLDOC'
collector_name: mssql_standard
metrics:
  - metric_name: mssql_up
    type: gauge
    help: "MSSQL instance UP status"
    values: [status]
    query: "SELECT 1 AS status"

  - metric_name: mssql_product_version
    type: gauge
    help: "MSSQL product version (Major.Minor)"
    values: [version]
    query: |
      SELECT CAST(SERVERPROPERTY('ProductMajorVersion') AS float)
        + CAST(SERVERPROPERTY('ProductMinorVersion') AS float) / 10.0 AS version

  - metric_name: mssql_instance_local_time
    type: gauge
    help: "Seconds since epoch on local instance"
    values: [timestamp]
    query: "SELECT DATEDIFF(SECOND, '1970-01-01', GETUTCDATE()) AS timestamp"

  - metric_name: mssql_connections
    type: gauge
    help: "Number of active connections by database"
    key_labels: [database, state]
    values: [connections]
    query: |
      SELECT DB_NAME(dbid) AS [database], 'current' AS [state], COUNT(*) AS connections
      FROM sys.sysprocesses WHERE dbid > 0 GROUP BY dbid

  - metric_name: mssql_client_connections
    type: gauge
    help: "Number of active client connections"
    values: [connections]
    query: "SELECT COUNT(*) AS connections FROM sys.dm_exec_connections"

  - metric_name: mssql_deadlocks
    type: gauge
    help: "Number of deadlocks (cumulative)"
    values: [deadlocks]
    query: |
      SELECT cntr_value AS deadlocks FROM sys.dm_os_performance_counters
      WHERE counter_name = 'Number of Deadlocks/sec' AND instance_name = '_Total'

  - metric_name: mssql_user_errors
    type: gauge
    help: "Number of user errors (cumulative)"
    values: [errors]
    query: |
      SELECT cntr_value AS errors FROM sys.dm_os_performance_counters
      WHERE counter_name = 'Errors/sec' AND instance_name = 'User Errors'

  - metric_name: mssql_kill_connection_errors
    type: gauge
    help: "Number of kill connection errors (cumulative)"
    values: [errors]
    query: |
      SELECT cntr_value AS errors FROM sys.dm_os_performance_counters
      WHERE counter_name = 'Errors/sec' AND instance_name = 'Kill Connection Errors'

  - metric_name: mssql_page_life_expectancy
    type: gauge
    help: "Page life expectancy in seconds"
    values: [seconds]
    query: |
      SELECT cntr_value AS seconds FROM sys.dm_os_performance_counters
      WHERE counter_name = 'Page life expectancy' AND object_name LIKE '%Buffer Manager%'

  - metric_name: mssql_batch_requests
    type: gauge
    help: "Batch requests (cumulative)"
    values: [requests]
    query: |
      SELECT cntr_value AS requests FROM sys.dm_os_performance_counters
      WHERE counter_name = 'Batch Requests/sec'

  - metric_name: mssql_compilations
    type: gauge
    help: "SQL compilations (cumulative)"
    values: [compilations]
    query: |
      SELECT cntr_value AS compilations FROM sys.dm_os_performance_counters
      WHERE counter_name = 'SQL Compilations/sec'

  - metric_name: mssql_recompilations
    type: gauge
    help: "SQL re-compilations (cumulative)"
    values: [recompilations]
    query: |
      SELECT cntr_value AS recompilations FROM sys.dm_os_performance_counters
      WHERE counter_name = 'SQL Re-Compilations/sec'

  - metric_name: mssql_buffer_cache_hit_ratio
    type: gauge
    help: "Buffer cache hit ratio percentage"
    values: [ratio]
    query: |
      SELECT CAST(a.cntr_value AS float) / NULLIF(CAST(b.cntr_value AS float), 0) * 100.0 AS ratio
      FROM sys.dm_os_performance_counters a
      CROSS JOIN sys.dm_os_performance_counters b
      WHERE a.counter_name = 'Buffer cache hit ratio'
        AND a.object_name LIKE '%Buffer Manager%'
        AND b.counter_name = 'Buffer cache hit ratio base'
        AND b.object_name LIKE '%Buffer Manager%'

  - metric_name: mssql_checkpoint_pages
    type: gauge
    help: "Checkpoint pages (cumulative)"
    values: [pages]
    query: |
      SELECT cntr_value AS pages FROM sys.dm_os_performance_counters
      WHERE counter_name = 'Checkpoint pages/sec'

  - metric_name: mssql_io_stall
    type: gauge
    help: "IO stall time in milliseconds by database and type"
    key_labels: [database, type]
    values: [stall]
    query: |
      SELECT DB_NAME(database_id) AS [database], 'read' AS [type], SUM(io_stall_read_ms) AS stall
      FROM sys.dm_io_virtual_file_stats(NULL, NULL) GROUP BY database_id
      UNION ALL
      SELECT DB_NAME(database_id), 'write', SUM(io_stall_write_ms)
      FROM sys.dm_io_virtual_file_stats(NULL, NULL) GROUP BY database_id

  - metric_name: mssql_io_stall_total
    type: gauge
    help: "Total IO stall time in milliseconds by database"
    key_labels: [database]
    values: [stall]
    query: |
      SELECT DB_NAME(database_id) AS [database], SUM(io_stall) AS stall
      FROM sys.dm_io_virtual_file_stats(NULL, NULL) GROUP BY database_id

  - metric_name: mssql_database_filesize
    type: gauge
    help: "Database file size in bytes"
    key_labels: [database, type]
    values: [size]
    query: |
      SELECT DB_NAME(database_id) AS [database],
        CASE type WHEN 0 THEN 'data' WHEN 1 THEN 'log' ELSE 'other' END AS [type],
        SUM(CAST(size AS bigint) * 8192) AS size
      FROM sys.master_files GROUP BY database_id, type

  - metric_name: mssql_database_state
    type: gauge
    help: "Database state (0=ONLINE,1=RESTORING,2=RECOVERING,4=SUSPECT,6=OFFLINE)"
    key_labels: [database]
    values: [state]
    query: "SELECT name AS [database], state FROM sys.databases"
YAMLDOC
}

# 檢查 pmm-client 容器是否運行，並偵測 listen port
check_pmm_client() {
  if ! sudo docker ps --format '{{.Names}}' | grep -qx "${PMM_CLIENT_CONTAINER}"; then
    error "找不到運行中的 PMM Client 容器: ${PMM_CLIENT_CONTAINER}"
    echo "  請先啟動 PMM Client，或設定環境變數："
    echo "  export PMM_CLIENT_CONTAINER=your-container-name"
    exit 1
  fi
  info "PMM Client 容器: ${PMM_CLIENT_CONTAINER} ✓"

  # 自動偵測 pmm-agent listen port
  PMM_AGENT_PORT=$(sudo docker exec "${PMM_CLIENT_CONTAINER}" \
    grep -oP 'listen-port:\s*\K\d+' /usr/local/percona/pmm/config/pmm-agent.yaml 2>/dev/null || echo "")

  if [[ -z "$PMM_AGENT_PORT" || "$PMM_AGENT_PORT" == "7777" ]]; then
    # 嘗試預設 port
    if sudo docker exec "${PMM_CLIENT_CONTAINER}" pmm-admin status >/dev/null 2>&1; then
      PMM_AGENT_PORT=""  # 預設 port 可用，不需要額外指定
    else
      # 預設不通，嘗試常見替代 port
      for port in 17777 27777 37777; do
        if sudo docker exec "${PMM_CLIENT_CONTAINER}" pmm-admin status --pmm-agent-listen-port="${port}" >/dev/null 2>&1; then
          PMM_AGENT_PORT="${port}"
          break
        fi
      done
    fi
  fi

  # 建立 pmm-admin 的共用參數
  PMM_ADMIN_FLAGS=""
  if [[ -n "$PMM_AGENT_PORT" ]]; then
    PMM_ADMIN_FLAGS="--pmm-agent-listen-port=${PMM_AGENT_PORT}"
    info "pmm-agent listen port: ${PMM_AGENT_PORT}"
  fi
}

# 取得容器 IP
get_container_ip() {
  local container_name="$1"
  local ip
  ip=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null || true)
  echo "$ip"
}

# ============================================================
# MySQL / MariaDB
# ============================================================
add_mysql() {
  echo
  echo "═══════════════════════════════════════"
  echo "  新增 MySQL / MariaDB 監控"
  echo "═══════════════════════════════════════"
  echo

  # ----- 連線方式 -----
  echo "資料庫位置："
  echo "  1) Docker 容器（自動取得 IP）"
  echo "  2) 手動輸入 Host/IP"
  ask "請選擇 [1/2]: "
  read -r db_location

  local db_host db_port
  if [[ "$db_location" == "1" ]]; then
    show_running_containers
    local container_name
    container_name=$(read_input "資料庫容器名稱" "" "required")
    db_host=$(get_container_ip "$container_name")
    if [[ -z "$db_host" ]]; then
      error "無法取得容器 ${container_name} 的 IP，請確認容器名稱是否正確"
      return 1
    fi
    info "容器 IP: ${db_host}"
    db_port=$(read_input "Port（容器內部 port）" "3306")
  else
    db_host=$(read_input "資料庫 Host/IP" "127.0.0.1")
    db_port=$(read_input "Port" "3306")
  fi

  # ----- 認證 -----
  local db_user db_pass
  db_user=$(read_input "資料庫帳號（需有監控權限）" "pmm")
  db_pass=$(read_password "資料庫密碼")

  # ----- 服務名稱 -----
  local service_name
  service_name=$(read_input "PMM 服務名稱（例如 mariadb-prod-01）" "" "required")

  # ----- Query Source -----
  echo "Query Source："
  echo "  1) perfschema（推薦）"
  echo "  2) slowlog"
  local qs_choice query_source
  ask "請選擇 [1/2]: "
  read -r qs_choice
  case "$qs_choice" in
    2) query_source="slowlog" ;;
    *) query_source="perfschema" ;;
  esac

  # ----- 是否建立 PMM 帳號 -----
  echo
  ask "是否需要先在資料庫中建立 PMM 監控帳號？(y/N): "
  read -r create_user
  if [[ "$create_user" =~ ^[Yy]$ ]]; then
    local root_user root_pass
    root_user=$(read_input "管理員帳號" "root")
    root_pass=$(read_password "管理員密碼")

    info "建立 PMM 監控帳號 ..."
    # 偵測是 MariaDB 還是 MySQL（影響語法）
    sudo docker exec -i "${PMM_CLIENT_CONTAINER}" bash -c "
      mysql -h'${db_host}' -P'${db_port}' -u'${root_user}' -p'${root_pass}' -e \"
        CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_pass}';
        GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD ON *.* TO '${db_user}'@'%';
        GRANT SELECT ON performance_schema.* TO '${db_user}'@'%';
        FLUSH PRIVILEGES;
      \"
    " && info "帳號建立完成" || warn "帳號建立失敗，請手動建立"
  fi

  # ----- 確認 -----
  echo
  echo "──────────────────────────────────"
  echo "  類型:         MySQL/MariaDB"
  echo "  Host:         ${db_host}:${db_port}"
  echo "  帳號:         ${db_user}"
  echo "  服務名稱:     ${service_name}"
  echo "  Query Source: ${query_source}"
  echo "──────────────────────────────────"
  ask "確認加入？(Y/n): "
  read -r confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    warn "已取消"
    return 0
  fi

  # ----- 執行 -----
  info "註冊到 PMM ..."
  sudo docker exec -it "${PMM_CLIENT_CONTAINER}" pmm-admin add mysql \
    ${PMM_ADMIN_FLAGS} \
    --username="${db_user}" \
    --password="${db_pass}" \
    --host="${db_host}" \
    --port="${db_port}" \
    --service-name="${service_name}" \
    --query-source="${query_source}"

  info "MySQL/MariaDB 註冊完成: ${service_name}"
}

# ============================================================
# PostgreSQL
# ============================================================
add_postgresql() {
  echo
  echo "═══════════════════════════════════════"
  echo "  新增 PostgreSQL 監控"
  echo "═══════════════════════════════════════"
  echo

  # ----- 連線方式 -----
  echo "資料庫位置："
  echo "  1) Docker 容器（自動取得 IP）"
  echo "  2) 手動輸入 Host/IP"
  ask "請選擇 [1/2]: "
  read -r db_location

  local db_host db_port
  if [[ "$db_location" == "1" ]]; then
    show_running_containers
    local container_name
    container_name=$(read_input "資料庫容器名稱" "" "required")
    db_host=$(get_container_ip "$container_name")
    if [[ -z "$db_host" ]]; then
      error "無法取得容器 ${container_name} 的 IP，請確認容器名稱是否正確"
      return 1
    fi
    info "容器 IP: ${db_host}"
    db_port=$(read_input "Port（容器內部 port）" "5432")
  else
    db_host=$(read_input "資料庫 Host/IP" "127.0.0.1")
    db_port=$(read_input "Port" "5432")
  fi

  # ----- 認證 -----
  local db_user db_pass
  db_user=$(read_input "資料庫帳號（需有 pg_monitor 權限）" "pmm")
  db_pass=$(read_password "資料庫密碼")

  # ----- 資料庫名稱 -----
  local db_name
  db_name=$(read_input "資料庫名稱（pg_stat_statements 所在的 DB）" "postgres")

  # ----- 服務名稱 -----
  local service_name
  service_name=$(read_input "PMM 服務名稱（例如 postgres-prod-01）" "" "required")

  # ----- 是否建立 PMM 帳號 -----
  echo
  ask "是否需要先在資料庫中建立 PMM 監控帳號？(y/N): "
  read -r create_user
  if [[ "$create_user" =~ ^[Yy]$ ]]; then
    local admin_user admin_pass pg_container_or_host
    echo "建立帳號的方式："
    echo "  1) 透過 docker exec 進入 PG 容器"
    echo "  2) 透過 pmm-client 容器用 psql 連線"
    ask "請選擇 [1/2]: "
    read -r create_method

    admin_user=$(read_input "管理員帳號" "postgres")
    admin_pass=$(read_password "管理員密碼")

    if [[ "$create_method" == "1" ]]; then
      pg_container_or_host=$(read_input "PG 容器名稱")
      info "建立 PMM 監控帳號 ..."
      sudo docker exec -i "${pg_container_or_host}" psql -U "${admin_user}" -d "${db_name}" <<SQL && info "帳號建立完成" || warn "帳號建立失敗，請手動建立"
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${db_user}') THEN
    CREATE USER ${db_user} WITH PASSWORD '${db_pass}';
  END IF;
END
\$\$;
GRANT pg_monitor TO ${db_user};
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SQL
    else
      info "透過 pmm-client 容器建立帳號 ..."
      sudo docker exec -i "${PMM_CLIENT_CONTAINER}" bash -c "
        PGPASSWORD='${admin_pass}' psql -h '${db_host}' -p '${db_port}' -U '${admin_user}' -d '${db_name}' <<'EOSQL'
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${db_user}') THEN
    CREATE USER ${db_user} WITH PASSWORD '${db_pass}';
  END IF;
END
\$\$;
GRANT pg_monitor TO ${db_user};
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
EOSQL
      " && info "帳號建立完成" || warn "帳號建立失敗，請手動建立"
    fi
  fi

  # ----- 確認 -----
  echo
  echo "──────────────────────────────────"
  echo "  類型:       PostgreSQL"
  echo "  Host:       ${db_host}:${db_port}"
  echo "  帳號:       ${db_user}"
  echo "  資料庫:     ${db_name}"
  echo "  服務名稱:   ${service_name}"
  echo "  QAN Source: pgstatements"
  echo "──────────────────────────────────"
  ask "確認加入？(Y/n): "
  read -r confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    warn "已取消"
    return 0
  fi

  # ----- 執行 -----
  info "註冊到 PMM ..."
  sudo docker exec -it "${PMM_CLIENT_CONTAINER}" pmm-admin add postgresql \
    ${PMM_ADMIN_FLAGS} \
    --username="${db_user}" \
    --password="${db_pass}" \
    --host="${db_host}" \
    --port="${db_port}" \
    --database="${db_name}" \
    --service-name="${service_name}" \
    --query-source=pgstatements

  info "PostgreSQL 註冊完成: ${service_name}"
}

# ============================================================
# MSSQL（External Exporter）
# ============================================================
add_mssql() {
  echo
  echo "═══════════════════════════════════════"
  echo "  新增 MSSQL 監控（External Exporter）"
  echo "═══════════════════════════════════════"
  echo
  warn "MSSQL 使用 external exporter 方式，會額外啟動一個 mssql-exporter 容器"
  echo

  # ----- 連線方式 -----
  echo "MSSQL 位置："
  echo "  1) Docker 容器（自動取得 IP）"
  echo "  2) 手動輸入 Host/IP"
  ask "請選擇 [1/2]: "
  read -r db_location

  local db_host db_port
  if [[ "$db_location" == "1" ]]; then
    show_running_containers
    local container_name
    container_name=$(read_input "MSSQL 容器名稱" "mssql")
    db_host=$(get_container_ip "$container_name")
    if [[ -z "$db_host" ]]; then
      error "無法取得容器 ${container_name} 的 IP"
      return 1
    fi
    info "容器 IP: ${db_host}"
    db_port=$(read_input "Port（容器內部 port）" "1433")
  else
    db_host=$(read_input "MSSQL Host/IP")
    db_port=$(read_input "MSSQL Port" "1433")
  fi

  # ----- 認證 -----
  local db_user db_pass
  db_user=$(read_input "MSSQL 帳號" "pmm")
  db_pass=$(read_password "MSSQL 密碼")

  # ----- 服務與 Exporter 設定 -----
  local service_name exporter_name exporter_port docker_network mssql_env mssql_node
  service_name=$(read_input "PMM 服務名稱（例如 mssql-prod-01）" "" "required")
  mssql_env=$(read_input "Environment label（Dashboard 篩選用）" "production")
  mssql_node=$(read_input "Node label（Dashboard 篩選用）" "$(hostname -s)")
  exporter_name=$(read_input "Exporter 容器名稱" "mssql-exporter-${service_name}")
  exporter_port=$(read_input "Exporter 對外 Port" "9399")
  docker_network=$(read_input "Docker Network（讓 exporter 連到 MSSQL）" "pmm-net")

  # ----- 是否建立 PMM 帳號 -----
  echo
  ask "是否需要先在 MSSQL 中建立 PMM 監控帳號？(y/N): "
  read -r create_user
  if [[ "$create_user" =~ ^[Yy]$ ]]; then
    local sa_pass
    sa_pass=$(read_password "SA 密碼")
    local mssql_container
    mssql_container=$(read_input "MSSQL 容器名稱" "mssql")

    info "建立 PMM 監控帳號 ..."
    sudo docker exec -i "${mssql_container}" bash -lc "set +H
/opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P '${sa_pass}' -C \
  -Q \"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '${db_user}')
BEGIN
  CREATE LOGIN [${db_user}] WITH PASSWORD = '${db_pass}', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
END;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '${db_user}')
BEGIN
  CREATE USER [${db_user}] FOR LOGIN [${db_user}];
END;
ALTER SERVER ROLE sysadmin ADD MEMBER [${db_user}];
\"" && info "帳號建立完成" || warn "帳號建立失敗，請手動建立"
  fi

  # ----- 確認 -----
  echo
  echo "──────────────────────────────────"
  echo "  類型:           MSSQL (External)"
  echo "  MSSQL Host:     ${db_host}:${db_port}"
  echo "  帳號:           ${db_user}"
  echo "  服務名稱:       ${service_name}"
  echo "  Exporter:       ${exporter_name}"
  echo "  Exporter Port:  ${exporter_port}"
  echo "  Docker Network: ${docker_network}"
  echo "──────────────────────────────────"
  ask "確認加入？(Y/n): "
  read -r confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    warn "已取消"
    return 0
  fi

  # ----- 建立 Docker Network -----
  sudo docker network create "${docker_network}" 2>/dev/null || true

  # ----- 建立 Exporter 設定（YAML） -----
  local config_dir="/data/mssql-exporter/${service_name}"
  sudo mkdir -p "${config_dir}"

  local encoded_pass
  encoded_pass=$(url_encode_password "${db_pass}")
  local dsn="sqlserver://${db_user}:${encoded_pass}@${db_host}:${db_port}?encrypt=disable&TrustServerCertificate=true"

  write_mssql_exporter_config "${config_dir}/sql_exporter.yml" "${dsn}"
  write_mssql_collector "${config_dir}/mssql.collector.yml"
  info "Exporter 設定: ${config_dir}/"

  # ----- 啟動 Exporter -----
  info "啟動 MSSQL Exporter: ${exporter_name} ..."
  sudo docker rm -f "${exporter_name}" 2>/dev/null || true
  sudo docker run -d \
    --name "${exporter_name}" \
    --restart unless-stopped \
    --network "${docker_network}" \
    -v "${config_dir}/sql_exporter.yml:/etc/sql_exporter/sql_exporter.yml:ro" \
    -v "${config_dir}/mssql.collector.yml:/etc/sql_exporter/mssql.collector.yml:ro" \
    -p "${exporter_port}:9399" \
    "${MSSQL_EXPORTER_IMAGE}" \
    --config.file=/etc/sql_exporter/sql_exporter.yml

  info "等待 Exporter 啟動 ..."
  sleep 3

  # 驗證 exporter
  if curl -sf "http://127.0.0.1:${exporter_port}/metrics" >/dev/null 2>&1; then
    info "Exporter 運行正常 ✓"
  else
    warn "Exporter 可能尚未就緒，請稍後手動驗證: curl http://127.0.0.1:${exporter_port}/metrics"
  fi

  # ----- 加入 PMM -----
  info "註冊到 PMM ..."
  local node_id
  node_id=$(sudo docker exec -it "${PMM_CLIENT_CONTAINER}" pmm-admin status ${PMM_ADMIN_FLAGS} \
    | awk -F': ' '/Node ID/ {print $2}' | tr -d '\r\n')

  sudo docker exec -it "${PMM_CLIENT_CONTAINER}" pmm-admin add external \
    ${PMM_ADMIN_FLAGS} \
    --service-name="${service_name}" \
    --service-node-id="${node_id}" \
    --scheme="http" \
    --metrics-path="/metrics" \
    --listen-port="${exporter_port}" \
    --environment="${mssql_env}" \
    --custom-labels="dbtype=mssql,env=${mssql_env},node=${mssql_node}"

  info "MSSQL 註冊完成: ${service_name}"
  echo
  warn "提醒：PMM UI 沒有內建 MSSQL Dashboard，請手動 Import mssql.json"
}

# ============================================================
# 移除服務
# ============================================================
remove_service() {
  echo
  echo "═══════════════════════════════════════"
  echo "  移除 PMM 監控服務"
  echo "═══════════════════════════════════════"
  echo

  info "目前已註冊的服務："
  echo
  sudo docker exec -it "${PMM_CLIENT_CONTAINER}" pmm-admin list ${PMM_ADMIN_FLAGS}
  echo

  local service_name service_type
  service_name=$(read_input "要移除的服務名稱")
  echo "服務類型："
  echo "  1) mysql"
  echo "  2) postgresql"
  echo "  3) external (MSSQL)"
  ask "請選擇 [1/2/3]: "
  read -r type_choice

  case "$type_choice" in
    1) service_type="mysql" ;;
    2) service_type="postgresql" ;;
    3) service_type="external" ;;
    *) error "無效選擇"; return 1 ;;
  esac

  ask "確認移除 ${service_name}？(y/N): "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "已取消"
    return 0
  fi

  sudo docker exec -it "${PMM_CLIENT_CONTAINER}" pmm-admin remove ${PMM_ADMIN_FLAGS} "${service_type}" "${service_name}"
  info "已移除: ${service_name}"
}

# ============================================================
# 列出服務
# ============================================================
list_services() {
  echo
  info "目前已註冊的服務："
  echo
  sudo docker exec -it "${PMM_CLIENT_CONTAINER}" pmm-admin list ${PMM_ADMIN_FLAGS}
}

# ============================================================
# 一鍵加入 Demo 資料庫（deploy-demo-dbs.sh 建立的）
# ============================================================
add_demo_all() {
  section "一鍵加入 Demo 資料庫"

  # --- Demo 資料庫固定設定（與 deploy-demo-dbs.sh 一致）---
  local DEMO_MARIADB_CONTAINER="demo-mariadb"
  local DEMO_MARIADB_PMM_USER="pmm"
  local DEMO_MARIADB_PMM_PASS="PmmMaria!234"

  local DEMO_PG_CONTAINER="demo-postgres"
  local DEMO_PG_PMM_USER="pmm"
  local DEMO_PG_PMM_PASS="PmmPostgres!234"
  local DEMO_PG_DB="demo_shop"

  local DEMO_MSSQL_CONTAINER="demo-mssql"
  local DEMO_MSSQL_PMM_USER="pmm"
  local DEMO_MSSQL_PMM_PASS="Str0ng#Audit789!"

  # 檢查 Demo 容器是否都在跑
  local all_ok=true
  for c in "$DEMO_MARIADB_CONTAINER" "$DEMO_PG_CONTAINER" "$DEMO_MSSQL_CONTAINER"; do
    if sudo docker ps --format '{{.Names}}' | grep -qx "$c"; then
      info "${c} ✓"
    else
      error "${c} 未運行"
      all_ok=false
    fi
  done

  if [[ "$all_ok" != "true" ]]; then
    error "部分 Demo 容器未運行，請先執行 deploy-demo-dbs.sh"
    return 1
  fi
  echo

  # --- 取得容器 IP ---
  local mariadb_ip pg_ip mssql_ip
  mariadb_ip=$(get_container_ip "$DEMO_MARIADB_CONTAINER")
  pg_ip=$(get_container_ip "$DEMO_PG_CONTAINER")
  mssql_ip=$(get_container_ip "$DEMO_MSSQL_CONTAINER")

  echo "──────────────────────────────────────────────"
  echo "  MariaDB   : ${mariadb_ip}:3306  (${DEMO_MARIADB_CONTAINER})"
  echo "  PostgreSQL: ${pg_ip}:5432  (${DEMO_PG_CONTAINER})"
  echo "  MSSQL     : ${mssql_ip}:1433  (${DEMO_MSSQL_CONTAINER})"
  echo "──────────────────────────────────────────────"
  echo
  ask "確認全部加入 PMM？(Y/n): "
  read -r confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    warn "已取消"
    return 0
  fi

  local success=0 fail=0

  # --- MariaDB ---
  echo
  info "[1/3] 加入 MariaDB ..."
  if sudo docker exec "${PMM_CLIENT_CONTAINER}" pmm-admin add mysql \
    ${PMM_ADMIN_FLAGS} \
    --username="${DEMO_MARIADB_PMM_USER}" \
    --password="${DEMO_MARIADB_PMM_PASS}" \
    --host="${mariadb_ip}" \
    --port=3306 \
    --service-name="${DEMO_MARIADB_CONTAINER}" \
    --query-source=perfschema 2>&1; then
    info "MariaDB 加入成功 ✓"
    success=$((success + 1))
  else
    error "MariaDB 加入失敗"
    fail=$((fail + 1))
  fi

  # --- PostgreSQL ---
  echo
  info "[2/3] 加入 PostgreSQL ..."
  if sudo docker exec "${PMM_CLIENT_CONTAINER}" pmm-admin add postgresql \
    ${PMM_ADMIN_FLAGS} \
    --username="${DEMO_PG_PMM_USER}" \
    --password="${DEMO_PG_PMM_PASS}" \
    --host="${pg_ip}" \
    --port=5432 \
    --database="${DEMO_PG_DB}" \
    --service-name="${DEMO_PG_CONTAINER}" \
    --query-source=pgstatements 2>&1; then
    info "PostgreSQL 加入成功 ✓"
    success=$((success + 1))
  else
    error "PostgreSQL 加入失敗"
    fail=$((fail + 1))
  fi

  # --- MSSQL (External Exporter via sql_exporter) ---
  echo
  info "[3/3] 加入 MSSQL (External Exporter) ..."

  local exporter_port=9399
  local exporter_name="demo-mssql-exporter"
  local config_dir="/data/mssql-exporter/demo"
  sudo docker network create pmm-net 2>/dev/null || true

  # 確保 MSSQL 容器在 pmm-net 上
  sudo docker network connect pmm-net "${DEMO_MSSQL_CONTAINER}" 2>/dev/null || true

  # 建立 sql_exporter 設定（用容器名稱而非 IP，避免重啟後 IP 變動）
  sudo mkdir -p "${config_dir}"
  local encoded_pass
  encoded_pass=$(url_encode_password "${DEMO_MSSQL_PMM_PASS}")
  local dsn="sqlserver://${DEMO_MSSQL_PMM_USER}:${encoded_pass}@${DEMO_MSSQL_CONTAINER}:1433?encrypt=disable&TrustServerCertificate=true"

  write_mssql_exporter_config "${config_dir}/sql_exporter.yml" "${dsn}"
  write_mssql_collector "${config_dir}/mssql.collector.yml"

  # 啟動 exporter
  sudo docker rm -f "${exporter_name}" 2>/dev/null || true
  sudo docker run -d \
    --name "${exporter_name}" \
    --restart unless-stopped \
    --network pmm-net \
    -v "${config_dir}/sql_exporter.yml:/etc/sql_exporter/sql_exporter.yml:ro" \
    -v "${config_dir}/mssql.collector.yml:/etc/sql_exporter/mssql.collector.yml:ro" \
    -p "${exporter_port}:9399" \
    "${MSSQL_EXPORTER_IMAGE}" \
    --config.file=/etc/sql_exporter/sql_exporter.yml >/dev/null 2>&1

  info "等待 MSSQL Exporter 啟動 ..."
  sleep 5

  # 取得 Node ID 並加入 PMM
  local node_id
  node_id=$(sudo docker exec "${PMM_CLIENT_CONTAINER}" pmm-admin status ${PMM_ADMIN_FLAGS} \
    | awk -F': ' '/Node ID/ {print $2}' | tr -d '\r\n')

  if sudo docker exec "${PMM_CLIENT_CONTAINER}" pmm-admin add external \
    ${PMM_ADMIN_FLAGS} \
    --service-name="${DEMO_MSSQL_CONTAINER}" \
    --service-node-id="${node_id}" \
    --scheme="http" \
    --metrics-path="/metrics" \
    --listen-port="${exporter_port}" \
    --environment="demo" \
    --custom-labels="dbtype=mssql,env=demo,node=$(hostname -s)" 2>&1; then
    info "MSSQL 加入成功 ✓"
    success=$((success + 1))
  else
    error "MSSQL 加入失敗"
    fail=$((fail + 1))
  fi

  # --- 摘要 ---
  echo
  echo "══════════════════════════════════"
  info "完成：${success} 成功, ${fail} 失敗"
  echo "══════════════════════════════════"

  if [[ $success -gt 0 ]]; then
    echo
    info "已註冊的服務："
    sudo docker exec "${PMM_CLIENT_CONTAINER}" pmm-admin list ${PMM_ADMIN_FLAGS}
  fi
}

section() { echo -e "\n${BOLD}${CYAN}══════ $* ══════${NC}\n"; }

# ============================================================
# 主選單
# ============================================================
main_menu() {
  while true; do
    echo
    echo "╔═══════════════════════════════════════╗"
    echo "║      PMM 資料庫註冊管理工具           ║"
    echo "╠═══════════════════════════════════════╣"
    echo "║  d) 一鍵加入 Demo 資料庫（推薦）      ║"
    echo "║  1) 新增 MySQL / MariaDB              ║"
    echo "║  2) 新增 PostgreSQL                   ║"
    echo "║  3) 新增 MSSQL                        ║"
    echo "║  4) 列出已註冊服務                    ║"
    echo "║  5) 移除服務                          ║"
    echo "║  0) 離開                              ║"
    echo "╚═══════════════════════════════════════╝"
    ask "請選擇: "
    read -r choice

    case "$choice" in
      d|D) add_demo_all ;;
      1) add_mysql ;;
      2) add_postgresql ;;
      3) add_mssql ;;
      4) list_services ;;
      5) remove_service ;;
      0) echo "Bye!"; exit 0 ;;
      *) warn "無效選擇，請重新輸入" ;;
    esac
  done
}

# ============================================================
# Entry
# ============================================================
check_pmm_client
main_menu
