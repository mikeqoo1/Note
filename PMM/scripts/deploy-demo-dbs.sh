#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# PMM Demo 資料庫一鍵部署腳本
# 部署 MariaDB / PostgreSQL / MSSQL 三種資料庫
# 每種都包含：PMM 監控帳號 + Audit + 範例資料庫
# ============================================================

# ----- 設定區（可依環境調整）-----
DOCKER_NETWORK="${DOCKER_NETWORK:-pmm-net}"
DATA_ROOT="${DATA_ROOT:-/data/pmm-demo}"

# MariaDB
MARIADB_CONTAINER="demo-mariadb"
MARIADB_IMAGE="mariadb:11"
MARIADB_PORT="3307"
MARIADB_ROOT_PASS="DemoRoot!234"
MARIADB_PMM_USER="pmm"
MARIADB_PMM_PASS="PmmMaria!234"

# PostgreSQL
PG_CONTAINER="demo-postgres"
PG_IMAGE="postgres:16"
PG_PORT="5433"
PG_SUPERUSER="postgres"
PG_SUPERUSER_PASS="DemoPostgres!234"
PG_PMM_USER="pmm"
PG_PMM_PASS="PmmPostgres!234"

# MSSQL
MSSQL_CONTAINER="demo-mssql"
MSSQL_IMAGE="mcr.microsoft.com/mssql/server:2022-latest"
MSSQL_PORT="2433"
MSSQL_SA_PASS="DemoSa!23456"
MSSQL_PMM_USER="pmm"
MSSQL_PMM_PASS="Str0ng#Audit789!"

# ----- 顏色 -----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
section() { echo -e "\n${BOLD}${CYAN}══════ $* ══════${NC}\n"; }

# 等待容器內服務就緒
wait_for_container() {
  local container="$1" check_cmd="$2" max_wait="${3:-60}"
  local elapsed=0
  echo -n "  等待 ${container} 就緒 "
  while ! sudo docker exec -i "$container" bash -c "$check_cmd" >/dev/null 2>&1; do
    echo -n "."
    sleep 2
    elapsed=$((elapsed + 2))
    if [[ $elapsed -ge $max_wait ]]; then
      echo
      error "${container} 啟動逾時（${max_wait}s）"
      return 1
    fi
  done
  echo -e " ${GREEN}OK${NC}"
}

# ============================================================
# 前置作業
# ============================================================
prepare() {
  section "前置作業"

  info "建立 Docker Network: ${DOCKER_NETWORK}"
  sudo docker network create "${DOCKER_NETWORK}" 2>/dev/null || true

  info "建立資料目錄: ${DATA_ROOT}"
  sudo mkdir -p "${DATA_ROOT}"/{mariadb,postgres,mssql/audit}
  sudo chown -R 10001:0 "${DATA_ROOT}/mssql/audit"
  sudo chmod 750 "${DATA_ROOT}/mssql/audit"
}

# ============================================================
# MariaDB
# ============================================================
deploy_mariadb() {
  section "MariaDB (${MARIADB_CONTAINER})"

  # --- 自訂設定檔（含 Audit）---
  local cnf_dir="${DATA_ROOT}/mariadb/conf.d"
  sudo mkdir -p "$cnf_dir"
  sudo tee "${cnf_dir}/pmm-audit.cnf" >/dev/null <<'CNF'
[mariadb]
plugin_load_add=server_audit
server_audit_logging=ON
server_audit_events=CONNECT,QUERY_DDL,QUERY_DML,QUERY_DCL,TABLE
server_audit_output_type=file
server_audit_file_path=/var/lib/mysql/server_audit.log
server_audit_file_rotate_size=104857600
server_audit_file_rotations=10

# PMM perfschema
performance_schema=ON
CNF

  # --- 啟動容器 ---
  info "啟動容器 ..."
  sudo docker rm -f "${MARIADB_CONTAINER}" 2>/dev/null || true
  sudo docker run -d \
    --name "${MARIADB_CONTAINER}" \
    --restart unless-stopped \
    --network "${DOCKER_NETWORK}" \
    -e "MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASS}" \
    -p "${MARIADB_PORT}:3306" \
    -v "${DATA_ROOT}/mariadb/data:/var/lib/mysql" \
    -v "${cnf_dir}:/etc/mysql/conf.d:ro" \
    "${MARIADB_IMAGE}"

  wait_for_container "${MARIADB_CONTAINER}" \
    "mariadb -uroot -p'${MARIADB_ROOT_PASS}' -e 'SELECT 1'" 60

  # --- PMM 帳號 ---
  info "建立 PMM 監控帳號 ..."
  sudo docker exec -i "${MARIADB_CONTAINER}" \
    mariadb -uroot -p"${MARIADB_ROOT_PASS}" <<SQL
CREATE USER IF NOT EXISTS '${MARIADB_PMM_USER}'@'%' IDENTIFIED BY '${MARIADB_PMM_PASS}';
GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD ON *.* TO '${MARIADB_PMM_USER}'@'%';
GRANT SELECT ON performance_schema.* TO '${MARIADB_PMM_USER}'@'%';
FLUSH PRIVILEGES;
SQL

  # --- 範例資料庫 ---
  info "建立範例資料庫 demo_shop ..."
  sudo docker exec -i "${MARIADB_CONTAINER}" \
    mariadb -uroot -p"${MARIADB_ROOT_PASS}" <<'SQL'
CREATE DATABASE IF NOT EXISTS demo_shop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE demo_shop;

CREATE TABLE IF NOT EXISTS customers (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  email       VARCHAR(200) NOT NULL,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(200) NOT NULL,
  price       DECIMAL(10,2) NOT NULL,
  stock       INT DEFAULT 0,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  customer_id  INT NOT NULL,
  product_id   INT NOT NULL,
  quantity     INT NOT NULL DEFAULT 1,
  total_price  DECIMAL(10,2) NOT NULL,
  order_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(id),
  FOREIGN KEY (product_id)  REFERENCES products(id)
);

INSERT IGNORE INTO customers (id, name, email) VALUES
  (1, 'Alice Wang',   'alice@example.com'),
  (2, 'Bob Chen',     'bob@example.com'),
  (3, 'Carol Lin',    'carol@example.com'),
  (4, 'David Liu',    'david@example.com'),
  (5, 'Eve Huang',    'eve@example.com');

INSERT IGNORE INTO products (id, name, price, stock) VALUES
  (1, 'Mechanical Keyboard', 2500.00, 50),
  (2, 'Wireless Mouse',       800.00, 120),
  (3, '27\" 4K Monitor',     8500.00, 30),
  (4, 'USB-C Hub',            650.00, 200),
  (5, 'Laptop Stand',         450.00, 80);

INSERT IGNORE INTO orders (id, customer_id, product_id, quantity, total_price) VALUES
  (1, 1, 1, 1,  2500.00),
  (2, 1, 2, 2,  1600.00),
  (3, 2, 3, 1,  8500.00),
  (4, 3, 4, 3,  1950.00),
  (5, 4, 5, 1,   450.00),
  (6, 5, 1, 2,  5000.00),
  (7, 2, 2, 1,   800.00),
  (8, 3, 3, 1,  8500.00),
  (9, 4, 4, 5,  3250.00),
  (10,5, 5, 2,   900.00);
SQL

  # --- 驗證 Audit ---
  info "驗證 Audit 狀態 ..."
  sudo docker exec -i "${MARIADB_CONTAINER}" \
    mariadb -uroot -p"${MARIADB_ROOT_PASS}" \
    -e "SHOW GLOBAL VARIABLES LIKE 'server_audit%';" 2>/dev/null | grep -E "logging|events|file_path" || warn "Audit 驗證失敗，請檢查 plugin"

  info "MariaDB 部署完成"
  echo "  連線: mysql -h127.0.0.1 -P${MARIADB_PORT} -uroot -p'${MARIADB_ROOT_PASS}' demo_shop"
}

# ============================================================
# PostgreSQL
# ============================================================
deploy_postgresql() {
  section "PostgreSQL (${PG_CONTAINER})"

  # --- 啟動容器（含 pg_stat_statements + pgaudit）---
  info "啟動容器 ..."
  sudo docker rm -f "${PG_CONTAINER}" 2>/dev/null || true
  sudo docker run -d \
    --name "${PG_CONTAINER}" \
    --restart unless-stopped \
    --network "${DOCKER_NETWORK}" \
    -e "POSTGRES_USER=${PG_SUPERUSER}" \
    -e "POSTGRES_PASSWORD=${PG_SUPERUSER_PASS}" \
    -e "POSTGRES_DB=postgres" \
    -p "${PG_PORT}:5432" \
    -v "${DATA_ROOT}/postgres/data:/var/lib/postgresql/data" \
    "${PG_IMAGE}" \
    postgres \
      -c shared_preload_libraries=pg_stat_statements \
      -c pg_stat_statements.track=all \
      -c track_activity_query_size=2048 \
      -c logging_collector=on \
      -c log_destination=stderr \
      -c "log_line_prefix=%m [%p] %u@%d %h " \
      -c log_statement=ddl

  wait_for_container "${PG_CONTAINER}" \
    "pg_isready -U ${PG_SUPERUSER}" 60

  # --- 嘗試安裝 pgaudit ---
  info "嘗試安裝 pgaudit ..."
  if sudo docker exec -i "${PG_CONTAINER}" bash -c "
    apt-get update -qq && apt-get install -y -qq postgresql-16-pgaudit >/dev/null 2>&1
  "; then
    info "pgaudit 安裝成功，重啟以載入 ..."
    sudo docker exec -i "${PG_CONTAINER}" \
      psql -U "${PG_SUPERUSER}" -d postgres \
      -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements,pgaudit';"
    sudo docker restart "${PG_CONTAINER}"
    wait_for_container "${PG_CONTAINER}" "pg_isready -U ${PG_SUPERUSER}" 60

    sudo docker exec -i "${PG_CONTAINER}" \
      psql -U "${PG_SUPERUSER}" -d postgres <<'SQL'
ALTER SYSTEM SET pgaudit.log = 'read,write,ddl,role';
ALTER SYSTEM SET pgaudit.log_catalog = 'off';
SELECT pg_reload_conf();
CREATE EXTENSION IF NOT EXISTS pgaudit;
SQL
    info "pgaudit 啟用完成"
  else
    warn "pgaudit 安裝失敗（image 不支援），跳過 pgaudit，其餘功能不受影響"
    warn "如需 pgaudit，請改用內建 pgaudit 的 image 或自建 Dockerfile"
  fi

  # --- pg_stat_statements ---
  info "建立 pg_stat_statements extension ..."
  sudo docker exec -i "${PG_CONTAINER}" \
    psql -U "${PG_SUPERUSER}" -d postgres \
    -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

  # --- PMM 帳號 ---
  info "建立 PMM 監控帳號 ..."
  sudo docker exec -i "${PG_CONTAINER}" \
    psql -U "${PG_SUPERUSER}" -d postgres <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PG_PMM_USER}') THEN
    CREATE USER ${PG_PMM_USER} WITH PASSWORD '${PG_PMM_PASS}';
  END IF;
END
\$\$;
GRANT pg_monitor TO ${PG_PMM_USER};
SQL

  # --- 範例資料庫 ---
  info "建立範例資料庫 demo_shop ..."
  sudo docker exec -i "${PG_CONTAINER}" \
    psql -U "${PG_SUPERUSER}" -d postgres \
    -c "SELECT 1 FROM pg_database WHERE datname = 'demo_shop'" | grep -q 1 || \
  sudo docker exec -i "${PG_CONTAINER}" \
    psql -U "${PG_SUPERUSER}" -d postgres \
    -c "CREATE DATABASE demo_shop;"

  sudo docker exec -i "${PG_CONTAINER}" \
    psql -U "${PG_SUPERUSER}" -d demo_shop \
    -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

  sudo docker exec -i "${PG_CONTAINER}" \
    psql -U "${PG_SUPERUSER}" -d demo_shop <<'SQL'
CREATE TABLE IF NOT EXISTS employees (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  department  VARCHAR(100) NOT NULL,
  salary      NUMERIC(10,2) NOT NULL,
  hire_date   DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS projects (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(200) NOT NULL,
  budget      NUMERIC(12,2) NOT NULL,
  status      VARCHAR(20) DEFAULT 'active',
  start_date  DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS assignments (
  id          SERIAL PRIMARY KEY,
  employee_id INT REFERENCES employees(id),
  project_id  INT REFERENCES projects(id),
  role        VARCHAR(50) NOT NULL,
  assigned_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO employees (name, department, salary) VALUES
  ('Alice Wang',   'Engineering', 85000.00),
  ('Bob Chen',     'Engineering', 78000.00),
  ('Carol Lin',    'Design',      72000.00),
  ('David Liu',    'PM',          80000.00),
  ('Eve Huang',    'QA',          70000.00),
  ('Frank Wu',     'Engineering', 90000.00),
  ('Grace Lee',    'Design',      75000.00),
  ('Henry Tsai',   'PM',          82000.00)
ON CONFLICT DO NOTHING;

INSERT INTO projects (name, budget, status) VALUES
  ('Website Redesign',    150000.00, 'active'),
  ('Mobile App v2',       300000.00, 'active'),
  ('Data Pipeline',       200000.00, 'planning'),
  ('Security Audit',       80000.00, 'completed')
ON CONFLICT DO NOTHING;

INSERT INTO assignments (employee_id, project_id, role) VALUES
  (1, 1, 'Backend Lead'),
  (2, 1, 'Frontend Dev'),
  (3, 1, 'UI Designer'),
  (4, 2, 'Project Manager'),
  (5, 2, 'QA Lead'),
  (6, 2, 'Backend Dev'),
  (7, 3, 'UX Designer'),
  (8, 3, 'Project Manager'),
  (1, 4, 'Security Lead'),
  (5, 4, 'QA Engineer')
ON CONFLICT DO NOTHING;
SQL

  info "PostgreSQL 部署完成"
  echo "  連線: psql -h127.0.0.1 -p${PG_PORT} -U${PG_SUPERUSER} -d demo_shop"
}

# ============================================================
# MSSQL
# ============================================================
deploy_mssql() {
  section "MSSQL (${MSSQL_CONTAINER})"

  # --- 啟動容器（掛載 audit 目錄）---
  info "啟動容器 ..."
  sudo docker rm -f "${MSSQL_CONTAINER}" 2>/dev/null || true
  sudo docker run -d \
    --name "${MSSQL_CONTAINER}" \
    --restart unless-stopped \
    --network "${DOCKER_NETWORK}" \
    -e "ACCEPT_EULA=Y" \
    -e "MSSQL_SA_PASSWORD=${MSSQL_SA_PASS}" \
    -e "MSSQL_PID=Express" \
    -p "${MSSQL_PORT}:1433" \
    -v "${DATA_ROOT}/mssql/audit:/var/opt/mssql/audit" \
    "${MSSQL_IMAGE}"

  wait_for_container "${MSSQL_CONTAINER}" \
    "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '${MSSQL_SA_PASS}' -C -Q 'SELECT 1'" 90

  # --- 用來執行 SQL 的 helper ---
  run_mssql() {
    sudo docker exec -i "${MSSQL_CONTAINER}" \
      /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "${MSSQL_SA_PASS}" -C "$@"
  }

  # --- PMM 帳號 ---
  info "建立 PMM 監控帳號 ..."
  run_mssql <<SQL
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '${MSSQL_PMM_USER}')
BEGIN
  CREATE LOGIN [${MSSQL_PMM_USER}] WITH PASSWORD = '${MSSQL_PMM_PASS}',
    CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '${MSSQL_PMM_USER}')
BEGIN
  CREATE USER [${MSSQL_PMM_USER}] FOR LOGIN [${MSSQL_PMM_USER}];
END
GO
ALTER SERVER ROLE sysadmin ADD MEMBER [${MSSQL_PMM_USER}];
GO
SQL

  # --- Server Audit ---
  info "建立 Server Audit ..."
  run_mssql <<'SQL'
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'demo_audit')
BEGIN
  CREATE SERVER AUDIT [demo_audit]
  TO FILE (FILEPATH = N'/var/opt/mssql/audit/', MAXSIZE = 512 MB, MAX_ROLLOVER_FILES = 10)
  WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
END
GO
ALTER SERVER AUDIT [demo_audit] WITH (STATE = ON);
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'demo_server_spec')
BEGIN
  CREATE SERVER AUDIT SPECIFICATION [demo_server_spec]
  FOR SERVER AUDIT [demo_audit]
  ADD (FAILED_LOGIN_GROUP),
  ADD (SUCCESSFUL_LOGIN_GROUP),
  ADD (SERVER_PERMISSION_CHANGE_GROUP),
  ADD (DATABASE_CHANGE_GROUP);
END
GO
ALTER SERVER AUDIT SPECIFICATION [demo_server_spec] WITH (STATE = ON);
GO
SQL

  # --- 範例資料庫 ---
  info "建立範例資料庫 demo_shop ..."
  run_mssql <<'SQL'
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'demo_shop')
BEGIN
  CREATE DATABASE demo_shop;
END
GO
SQL

  run_mssql -d demo_shop <<'SQL'
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'departments')
BEGIN
  CREATE TABLE departments (
    id    INT IDENTITY(1,1) PRIMARY KEY,
    name  NVARCHAR(100) NOT NULL,
    head  NVARCHAR(100)
  );

  INSERT INTO departments (name, head) VALUES
    (N'Engineering',  N'Alice Wang'),
    (N'Design',       N'Carol Lin'),
    (N'PM',           N'David Liu'),
    (N'QA',           N'Eve Huang'),
    (N'Sales',        N'Frank Wu');
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'tickets')
BEGIN
  CREATE TABLE tickets (
    id             INT IDENTITY(1,1) PRIMARY KEY,
    title          NVARCHAR(200) NOT NULL,
    description    NVARCHAR(MAX),
    status         NVARCHAR(20)  DEFAULT 'open',
    priority       NVARCHAR(10)  DEFAULT 'medium',
    department_id  INT REFERENCES departments(id),
    created_at     DATETIME2 DEFAULT GETDATE()
  );

  INSERT INTO tickets (title, description, status, priority, department_id) VALUES
    (N'Fix login page bug',       N'Login button not responding on mobile',  'open',        'high',   1),
    (N'Redesign dashboard',       N'New UI mockup for Q2 dashboard',         'in_progress', 'medium', 2),
    (N'Update API docs',          N'REST API v2 documentation update',       'open',        'low',    3),
    (N'Performance regression',   N'Page load time increased by 200ms',      'open',        'high',   1),
    (N'Security patch review',    N'Review CVE-2024-XXXX patch',             'in_progress', 'high',   4),
    (N'New landing page',         N'Marketing requested new landing page',   'open',        'medium', 2),
    (N'Deploy automation',        N'Set up CI/CD for staging',               'completed',   'medium', 1),
    (N'Client demo prep',         N'Prepare demo environment for client',    'open',        'high',   5),
    (N'Database backup review',   N'Verify backup strategy for production',  'in_progress', 'high',   1),
    (N'Quarterly report',         N'Generate Q1 performance metrics',        'completed',   'low',    3);
END
GO
SQL

  # --- Database Audit Specification ---
  info "建立 Database Audit Specification (demo_shop) ..."
  run_mssql -d demo_shop <<'SQL'
IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'demo_db_spec')
BEGIN
  CREATE DATABASE AUDIT SPECIFICATION [demo_db_spec]
  FOR SERVER AUDIT [demo_audit]
  ADD (DATABASE_OBJECT_ACCESS_GROUP),
  ADD (SCHEMA_OBJECT_CHANGE_GROUP),
  ADD (DATABASE_PRINCIPAL_CHANGE_GROUP);
END
GO
ALTER DATABASE AUDIT SPECIFICATION [demo_db_spec] WITH (STATE = ON);
GO
SQL

  info "MSSQL 部署完成"
  echo "  連線: sqlcmd -S 127.0.0.1,${MSSQL_PORT} -U sa -P '${MSSQL_SA_PASS}' -C -d demo_shop"
}

# ============================================================
# 摘要
# ============================================================
print_summary() {
  section "部署完成摘要"

  cat <<EOF
┌──────────┬───────────────────────┬──────────┬──────────────────────────────┐
│ 資料庫   │ 容器名稱              │ Port     │ Demo DB                      │
├──────────┼───────────────────────┼──────────┼──────────────────────────────┤
│ MariaDB  │ ${MARIADB_CONTAINER}        │ ${MARIADB_PORT}      │ demo_shop (customers/orders) │
│ Postgres │ ${PG_CONTAINER}      │ ${PG_PORT}      │ demo_shop (employees/proj.)  │
│ MSSQL    │ ${MSSQL_CONTAINER}         │ ${MSSQL_PORT}      │ demo_shop (tickets/depts)    │
└──────────┴───────────────────────┴──────────┴──────────────────────────────┘

PMM 監控帳號：
  MariaDB  → ${MARIADB_PMM_USER} / ${MARIADB_PMM_PASS}
  Postgres → ${PG_PMM_USER} / ${PG_PMM_PASS}
  MSSQL    → ${MSSQL_PMM_USER} / ${MSSQL_PMM_PASS}

Audit：
  MariaDB  → server_audit plugin（log: /var/lib/mysql/server_audit.log）
  Postgres → pgaudit（如安裝成功）+ log_statement=ddl
  MSSQL    → SQL Server Audit（/var/opt/mssql/audit/*.sqlaudit）

下一步：
  用 add-db.sh 將這些資料庫註冊到 PMM
  或手動執行：
    sudo docker exec -it pmm-client pmm-admin add mysql \\
      --username=${MARIADB_PMM_USER} --password='${MARIADB_PMM_PASS}' \\
      --host=\$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${MARIADB_CONTAINER}) \\
      --port=3306 --service-name=${MARIADB_CONTAINER} --query-source=perfschema
EOF
}

# ============================================================
# 清除功能
# ============================================================
cleanup() {
  section "清除所有 Demo 資料庫"

  warn "即將刪除以下容器與資料："
  echo "  容器: ${MARIADB_CONTAINER}, ${PG_CONTAINER}, ${MSSQL_CONTAINER}"
  echo "  資料: ${DATA_ROOT}"
  echo

  echo -en "${CYAN}確認刪除？(y/N): ${NC}"
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "已取消"
    exit 0
  fi

  sudo docker rm -f "${MARIADB_CONTAINER}" "${PG_CONTAINER}" "${MSSQL_CONTAINER}" 2>/dev/null || true
  sudo rm -rf "${DATA_ROOT}"
  info "清除完成"
}

# ============================================================
# 使用說明
# ============================================================
usage() {
  cat <<EOF
Usage: $0 [COMMAND]

Commands:
  all         部署全部三種資料庫（預設）
  mariadb     只部署 MariaDB
  postgresql  只部署 PostgreSQL
  mssql       只部署 MSSQL
  cleanup     清除所有 Demo 資料庫與資料
  help        顯示此說明

Environment Variables:
  DOCKER_NETWORK   Docker network 名稱  (預設: pmm-net)
  DATA_ROOT        資料根目錄            (預設: /data/pmm-demo)

Examples:
  sudo bash $0                    # 部署全部
  sudo bash $0 mariadb            # 只部署 MariaDB
  sudo bash $0 cleanup            # 清除全部
  DATA_ROOT=/tmp/demo bash $0     # 自訂資料目錄
EOF
}

# ============================================================
# Main
# ============================================================
main() {
  local cmd="${1:-all}"

  case "$cmd" in
    all)
      prepare
      deploy_mariadb
      deploy_postgresql
      deploy_mssql
      print_summary
      ;;
    mariadb)
      prepare
      deploy_mariadb
      ;;
    postgresql|postgres|pg)
      prepare
      deploy_postgresql
      ;;
    mssql)
      prepare
      deploy_mssql
      ;;
    cleanup|clean)
      cleanup
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      error "未知指令: ${cmd}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
