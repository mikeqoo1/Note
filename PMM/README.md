# 真實使用情境

![alt text](使用情境.png)

```txt
[A Host]
 ├─ pmm-agent           ← 裝在 host（只裝一次）
 │   ├─ node_exporter   ← 主機 CPU / RAM / Disk
 │   ├─ mysqld_exporter / postgres_exporter / redis_exporter
 │   └─ 負責把資料送到 PMM Server
 │
 ├─ MariaDB container
 ├─ Redis container
 └─ PostgreSQL container

[PMM Server] (Docker)
 └─ 收 metrics + UI
```

## A主機的問題 (234)

1) 安裝 pmm-agent

```bash
sduo yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm
sduo percona-release enable pmm3-client release
sduo yum install -y pmm-client
```

2) 因為 pmm-agent 的 7777 被佔用所以要去修改然後重新設定

```bash
sudo vi /usr/local/percona/pmm/config/pmm-agent.yaml

改port

sudo pmm-agent setup \
  --config-file=/usr/local/percona/pmm/config/pmm-agent.yaml \
  --server-address=192.168.199.234:18443 \
  --server-username=admin \
  --server-password='Aa123456' \
  --server-insecure-tls \
  --force

sudo systemctl restart pmm-agent
```

3) 因為改 Port 所以 pmm-admin 指令需要修改增加 --pmm-agent-listen-port

```bash
sudo pmm-admin add mysql   --server-url=https://admin:Aa123456@192.168.199.234:18443   --server-insecure-tls   --pmm-agent-listen-port=17777   --username=資料庫帳號   --password='資料庫密碼'   --host=192.168.199.234   --port=3306   --service-name=mariadb-234   --query-source=slowlog
```

4) 同一台主機 不同容器的加入方式

![alt text](不同容器.png)

5) 使用容器的 IP 來加入節點

```bash
sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' noco_new_db

sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' hedgedoc-database-1

sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql
```

6) 建立資料庫帳號

```bash
docker exec -it noco_new_db psql -U noco_appsmith -d app_data

CREATE USER pmm WITH PASSWORD 'StrongPMMpass!';

GRANT pg_monitor TO pmm;
```

7) noco-db 加入監控

```bash
sudo pmm-admin add postgresql \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=172.17.0.6 \
  --port=5432 \
  --service-name=postgres-noco
```

8) hedgedoc 加入監控

```bash
sudo pmm-admin add postgresql \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=172.19.0.2 \
  --port=5432 \
  --service-name=postgres-hedgedoc-ip
```

9) mysql-apitable 加入監控

```bash
sudo pmm-admin add mysql \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=172.27.0.3 \
  --port=3306 \
  --service-name=mysql-apitable-3306
```

10) 驗證

```bash
sudo pmm-admin list \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --pmm-agent-listen-port=17777 \
  --server-insecure-tls
```

![alt text](驗證.png)

## B主機的問題 (134)

用容器安裝 pmm-client:3 並且註冊好遠端的 pmm-server (腳本:pmm-client.sh)

進入容器設相關資料庫服務

本地資料庫的加入方式如下

![alt text](本地資料庫.png)

```bash
sudo docker exec -it pmm-client bash -lc \
"pmm-admin add mysql \
  --username=資料庫帳號 \
  --password='資料庫密碼' \
  --host=127.0.0.1 \
  --port=3306 \
  --service-name='EMTS-QA-01-mariadb' \
  --query-source=perfschema"
```

容器資料庫的加入方式

簡單弄個PG資料庫

```yaml
services:
  postgres18:
    image: postgres:18
    container_name: postgres18
    restart: always
    environment:
      POSTGRES_USER: myuser
      POSTGRES_DB: mydb
      POSTGRES_PASSWORD: mypassword
    ports:
      - "5432:5432"
    volumes:
      - pg18_data:/var/lib/postgresql
    command:
        # 開 pg_stat_statements
      - "postgres"
      - "-c"
      - "shared_preload_libraries=pg_stat_statements"
      - "-c"
      - "pg_stat_statements.track=all"
      - "-c"
      - "track_activity_query_size=2048"

volumes:
  pg18_data:
```

```bash
# 建立 extension（每個 DB 要建一次）
sudo docker exec -it postgres18 psql -U myuser -d mydb -c \
"CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# 把 PG18 加進 PMM
sudo docker exec -it pmm-client pmm-admin add postgresql \
  --service-name=EMTS-QA-01-postgres18-qan \
  --host=127.0.0.1 \
  --port=5432 \
  --username=資料庫帳號 \
  --password='資料庫密碼' \
  --database=mydb \
  --query-source=pgstatements
```

![alt text](B主機.png)

## MSSQL 的設定

sudo docker network create pmm-net 2>/dev/null || true

1) 先建立 MSSQL Server 容器

```bash
sudo docker run -d \
  --name mssql \
  --restart unless-stopped \
  --network pmm-net \
  -e 'ACCEPT_EULA=Y' \
  -e 'MSSQL_SA_PASSWORD=YourStr0ng!Passw0rd' \
  -e "MSSQL_PID=Express" \
  -p 2433:1433 \
  mcr.microsoft.com/mssql/server:2022-latest
```

2) 建立 PMM 專用帳號

```bash
sudo docker exec -i mssql bash -lc 'set +H
/opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStr0ng!Passw0rd" \
  -C \
  -Q "
USE master;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '\''pmm'\'')
BEGIN
  DROP LOGIN pmm;
END;

CREATE LOGIN pmm WITH PASSWORD = '\''X9!aZ7#Qp2@Mssql'\'', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
CREATE USER pmm FOR LOGIN pmm;
ALTER SERVER ROLE sysadmin ADD MEMBER pmm;
"
'
```

3) 啟動 MSSQL Exporter（Prometheus）

建立 env 檔

```bash
sudo mkdir -p /data/mssql-exporter

sudo tee /data/mssql-exporter/env >/dev/null <<'EOF'
SERVER=mssql
PORT=1433
USERNAME=pmm
PASSWORD=X9!aZ7#Qp2@Mssql
ENCRYPT=true
TRUST_SERVER_CERTIFICATE=true
EXPOSE=4000
EOF

sudo chmod 600 /data/mssql-exporter/env
```

啟動 awaragi/mssql-exporter container

```bash
sudo docker rm -f mssql-exporter 2>/dev/null || true
sudo docker pull awaragi/prometheus-mssql-exporter:latest

sudo docker run -d \
  --name mssql-exporter \
  --restart unless-stopped \
  --network pmm-net \
  --env-file /data/mssql-exporter/env \
  -p 4000:4000 \
  awaragi/prometheus-mssql-exporter:latest
```

4) 加進 PMM（External exporter）

```bash
sudo docker exec -it pmm-client pmm-admin remove external "EMTS-QA-01-mssql" 2>/dev/null || true

NODE_ID=$(sudo docker exec -it pmm-client pmm-admin status \
  | awk -F': ' '/Node ID/ {print $2}' | tr -d '\r')

echo "Node ID = $NODE_ID"


sudo docker exec -it pmm-client pmm-admin add external \
  --service-name="EMTS-QA-01-mssql" \
  --service-node-id="$NODE_ID" \
  --scheme="http" \
  --metrics-path="/metrics" \
  --listen-port=4000 \
  --environment="qa" \
  --custom-labels="dbtype=mssql,env=qa,node=EMTS-QA-01" \
  --metrics-mode="pull"

```

5) 導入到UI上

因為UI並沒有支援 MSSQL 但是 我們的 exporter 有正常執行 所以他會知道

接下來把 mssql.json Import 進去就好了

![alt text](Import_msqql.png)

6) 完成

![alt text](mssql畫面示意圖.png)

## Audit 強化設定（含 MSSQL）

PMM 本身重點是 metrics 與 QAN，不是完整 Audit Log 儲存。  
建議分成兩條線同時做：

1) DB 原生 Audit（MariaDB / PostgreSQL / MSSQL）  
2) PMM 看效能異常，Audit Log 用檔案留存（或再送到 Loki / SIEM）

---

### 1) MariaDB Audit（server_audit）

先安裝 plugin（只要一次）：

```sql
INSTALL SONAME 'server_audit';
```

即時啟用：

```sql
SET GLOBAL server_audit_logging=ON;
SET GLOBAL server_audit_events='CONNECT,QUERY_DDL,QUERY_DML,QUERY_DCL,TABLE';
SET GLOBAL server_audit_output_type='file';
SET GLOBAL server_audit_file_path='/var/lib/mysql/server_audit.log';
SET GLOBAL server_audit_file_rotate_size=1073741824; -- 1GB
SET GLOBAL server_audit_file_rotations=30;
```

建議寫進 `my.cnf` 持久化：

```ini
[mariadb]
plugin_load_add=server_audit
server_audit_logging=ON
server_audit_events=CONNECT,QUERY_DDL,QUERY_DML,QUERY_DCL,TABLE
server_audit_output_type=file
server_audit_file_path=/var/lib/mysql/server_audit.log
server_audit_file_rotate_size=1073741824
server_audit_file_rotations=30
```

---

### 2) PostgreSQL Audit（pgaudit）

Docker 啟動參數加入（重點是 `shared_preload_libraries`）：

```yaml
command:
  - "postgres"
  - "-c"
  - "shared_preload_libraries=pg_stat_statements,pgaudit"
  - "-c"
  - "logging_collector=on"
  - "-c"
  - "log_destination=stderr"
  - "-c"
  - "log_line_prefix=%m [%p] %u@%d %h "
  - "-c"
  - "pgaudit.log=read,write,ddl,role"
  - "-c"
  - "pgaudit.log_catalog=off"
```

若 `CREATE EXTENSION pgaudit;` 回報找不到 extension，代表目前 image 沒內建 `pgaudit`，需要改成自建 image 安裝 `postgresql-XX-pgaudit` 套件，或使用已內建 `pgaudit` 的 Postgres image。

啟用 extension：

```bash
sudo docker exec -it postgres18 psql -U myuser -d mydb -c \
"CREATE EXTENSION IF NOT EXISTS pgaudit;"
```

---

### 3) MSSQL Audit（SQL Server Audit）

先把 audit 目錄掛載出來，避免容器重建後遺失：

```bash
sudo mkdir -p /data/mssql/audit
sudo chown -R 10001:0 /data/mssql/audit
sudo chmod 750 /data/mssql/audit
```

MSSQL container 建議改成：

```bash
sudo docker rm -f mssql 2>/dev/null || true
sudo docker run -d \
  --name mssql \
  --restart unless-stopped \
  --network pmm-net \
  -e 'ACCEPT_EULA=Y' \
  -e 'MSSQL_SA_PASSWORD=YourStr0ng!Passw0rd' \
  -e "MSSQL_PID=Express" \
  -p 2433:1433 \
  -v /data/mssql/audit:/var/opt/mssql/audit \
  mcr.microsoft.com/mssql/server:2022-latest
```

建立 Server Audit + Specification：

```bash
sudo docker exec -i mssql /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStr0ng!Passw0rd" -C <<'SQL'
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'pmm_audit')
BEGIN
  CREATE SERVER AUDIT [pmm_audit]
  TO FILE (FILEPATH = N'/var/opt/mssql/audit/', MAXSIZE = 1 GB, MAX_ROLLOVER_FILES = 30)
  WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
END
GO
ALTER SERVER AUDIT [pmm_audit] WITH (STATE = ON);
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'pmm_server_spec')
BEGIN
  CREATE SERVER AUDIT SPECIFICATION [pmm_server_spec]
  FOR SERVER AUDIT [pmm_audit]
  ADD (FAILED_LOGIN_GROUP),
  ADD (SUCCESSFUL_LOGIN_GROUP),
  ADD (SERVER_PERMISSION_CHANGE_GROUP);
END
GO
ALTER SERVER AUDIT SPECIFICATION [pmm_server_spec] WITH (STATE = ON);
GO
SQL
```

針對單一業務 DB（例如 `appdb`）加上 DB 層級稽核：

```bash
sudo docker exec -i mssql /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStr0ng!Passw0rd" -C <<'SQL'
USE [appdb];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'pmm_db_spec')
BEGIN
  CREATE DATABASE AUDIT SPECIFICATION [pmm_db_spec]
  FOR SERVER AUDIT [pmm_audit]
  ADD (DATABASE_OBJECT_ACCESS_GROUP),
  ADD (SCHEMA_OBJECT_CHANGE_GROUP),
  ADD (DATABASE_PRINCIPAL_CHANGE_GROUP);
END
GO
ALTER DATABASE AUDIT SPECIFICATION [pmm_db_spec] WITH (STATE = ON);
GO
SQL
```

查最近 Audit 事件：

```bash
sudo docker exec -i mssql /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "YourStr0ng!Passw0rd" -C -Q "
SELECT TOP (100)
  event_time,
  action_id,
  succeeded,
  server_principal_name,
  database_name,
  object_name,
  statement
FROM sys.fn_get_audit_file('/var/opt/mssql/audit/*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;"
```

---

### 4) PMM 與 Audit 的搭配方式

1) PMM：看 CPU/IO、慢查詢、鎖等待、QPS、錯誤率  
2) Audit：看「誰在什麼時間對哪個物件做了什麼」  
3) 告警建議：先在 PMM 針對 Failed Login、Connections Spike、Query Latency 異常設告警，再回頭對照 Audit Log
