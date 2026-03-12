#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# PMM 資料庫註冊腳本（互動式）
# 支援：MySQL/MariaDB、PostgreSQL、MSSQL
# PMM Client 以容器方式運行
# ============================================================

# ----- 預設值 -----
PMM_CLIENT_CONTAINER="${PMM_CLIENT_CONTAINER:-pmm-client}"
MSSQL_EXPORTER_IMAGE="awaragi/prometheus-mssql-exporter:latest"

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
  local service_name exporter_name exporter_port docker_network
  service_name=$(read_input "PMM 服務名稱（例如 mssql-prod-01）" "" "required")
  exporter_name=$(read_input "Exporter 容器名稱" "mssql-exporter-${service_name}")
  exporter_port=$(read_input "Exporter 對外 Port" "4000")
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
  CREATE LOGIN [${db_user}] WITH PASSWORD = '${db_pass}', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
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

  # ----- 建立 Exporter env 檔 -----
  local env_dir="/data/mssql-exporter/${service_name}"
  sudo mkdir -p "${env_dir}"
  sudo tee "${env_dir}/env" >/dev/null <<EOF
SERVER=${db_host}
PORT=${db_port}
USERNAME=${db_user}
PASSWORD=${db_pass}
ENCRYPT=true
TRUST_SERVER_CERTIFICATE=true
EXPOSE=${exporter_port}
EOF
  sudo chmod 600 "${env_dir}/env"
  info "Exporter env 檔: ${env_dir}/env"

  # ----- 啟動 Exporter -----
  info "啟動 MSSQL Exporter: ${exporter_name} ..."
  sudo docker rm -f "${exporter_name}" 2>/dev/null || true
  sudo docker run -d \
    --name "${exporter_name}" \
    --restart unless-stopped \
    --network "${docker_network}" \
    --env-file "${env_dir}/env" \
    -p "${exporter_port}:4000" \
    "${MSSQL_EXPORTER_IMAGE}"

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
    --environment="production" \
    --custom-labels="dbtype=mssql,service=${service_name}" \
    --metrics-mode="pull"

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
  local DEMO_MSSQL_PMM_PASS="PmmMssql!234"

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

  # --- MSSQL (External Exporter) ---
  echo
  info "[3/3] 加入 MSSQL (External Exporter) ..."

  # 建立 exporter env
  local exporter_port=4000
  local exporter_name="demo-mssql-exporter"
  sudo docker network create pmm-net 2>/dev/null || true

  sudo mkdir -p /data/mssql-exporter/demo
  sudo tee /data/mssql-exporter/demo/env >/dev/null <<EOF
SERVER=${mssql_ip}
PORT=1433
USERNAME=${DEMO_MSSQL_PMM_USER}
PASSWORD=${DEMO_MSSQL_PMM_PASS}
ENCRYPT=true
TRUST_SERVER_CERTIFICATE=true
EXPOSE=${exporter_port}
EOF
  sudo chmod 600 /data/mssql-exporter/demo/env

  # 啟動 exporter
  sudo docker rm -f "${exporter_name}" 2>/dev/null || true
  sudo docker run -d \
    --name "${exporter_name}" \
    --restart unless-stopped \
    --network pmm-net \
    --env-file /data/mssql-exporter/demo/env \
    -p "${exporter_port}:4000" \
    "${MSSQL_EXPORTER_IMAGE}" >/dev/null 2>&1

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
    --custom-labels="dbtype=mssql,service=demo" \
    --metrics-mode="pull" 2>&1; then
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
