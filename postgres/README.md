# PostgreSQL 18 Podman 部署與升級指南

> 適用版本：PostgreSQL 18.x  
> 部署環境：Podman / Podman Compose  
> 適用場景：正式環境（含資料持久化、Healthcheck、Secrets、升級機制）

---

## 📂 專案目錄結構

```bash
postgres18/
├─ .env
├─ podman-compose.yml
├─ secrets/
│  ├─ pg_password.txt
│  └─ pg_replication_pass.txt
├─ config/
│  ├─ postgresql.conf
│  └─ pg_hba.conf
├─ initdb/
│  └─ 001_init.sql
├─ scripts/
│  ├─ backup.sh
│  ├─ restore.sh
│  ├─ upgrade_minor.sh
│  ├─ upgrade_major_pgupgrade.sh
│  └─ upgrade_major_logical.sh
```

⚙️ 1. .env — 環境設定檔

集中管理所有變數。

```bash
POSTGRES_TAG=18.3
POSTGRES_USER=admin
POSTGRES_DB=coredb
TZ=Asia/Taipei

PG_PORT=5432
PGDATA_VOLUME=pgdata18
PGLOG_VOLUME=pglog18

MAX_CONNECTIONS=300
SHARED_BUFFERS=4GB
WORK_MEM=16MB
MAINTENANCE_WORK_MEM=1GB
EFFECTIVE_CACHE_SIZE=12GB
```

🧩 2. podman-compose.yml — 佈署設定

```bash
version: '3.8'

services:
  postgres:
    image: docker.io/library/postgres:${POSTGRES_TAG}
    container_name: postgres18
    restart: always
    ports:
      - "${PG_PORT}:5432"
    environment:
      POSTGRES_USER: "${POSTGRES_USER}"
      POSTGRES_PASSWORD_FILE: /run/secrets/pg_password
      POSTGRES_DB: "${POSTGRES_DB}"
      TZ: "${TZ}"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 6
    volumes:
      - ${PGDATA_VOLUME}:/var/lib/postgresql/data
      - ${PGLOG_VOLUME}:/var/log/postgresql
      - ./config/postgresql.conf:/etc/postgresql/postgresql.conf:Z
      - ./config/pg_hba.conf:/etc/postgresql/pg_hba.conf:Z
      - ./initdb:/docker-entrypoint-initdb.d:Z
    secrets:
      - pg_password
    command: >
      postgres -c config_file=/etc/postgresql/postgresql.conf
               -c hba_file=/etc/postgresql/pg_hba.conf

secrets:
  pg_password:
    file: ./secrets/pg_password.txt

volumes:
  ${PGDATA_VOLUME}:
  ${PGLOG_VOLUME}:
```

🧾 3. PostgreSQL 設定檔

config/postgresql.conf

```bash
listen_addresses = '*'
port = 5432
max_connections = ${MAX_CONNECTIONS}

shared_buffers = ${SHARED_BUFFERS}
work_mem = ${WORK_MEM}
maintenance_work_mem = ${MAINTENANCE_WORK_MEM}
effective_cache_size = ${EFFECTIVE_CACHE_SIZE}

wal_level = replica
max_wal_senders = 10
wal_compression = on
archive_mode = off
synchronous_commit = on
checkpoint_timeout = 15min
max_wal_size = 8GB
min_wal_size = 2GB

logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%a.log'
log_rotation_age = '1d'
log_min_duration_statement = 1000
log_line_prefix = '%m [%p] %u@%d %h '

timezone = 'Asia/Taipei'
client_min_messages = notice
```

config/pg_hba.conf

```bash
# TYPE  DATABASE  USER    ADDRESS           METHOD
local   all       all                       trust
host    all       all     127.0.0.1/32      scram-sha-256
host    all       all     10.0.0.0/8        scram-sha-256
host    all       all     172.16.0.0/12     scram-sha-256
host    all       all     192.168.0.0/16    scram-sha-256
```

🧱 4. 初始化 SQL（選擇性）

initdb/001_init.sql

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

🚀 5. 啟動與維運

```bash
# 第一次啟動
podman-compose --env-file .env up -d

# 查看狀態
podman ps

# 查看日誌
podman logs -f postgres18

# 進入容器
podman exec -it postgres18 psql -U admin -d coredb
```

💾 6. 備份與還原

scripts/backup.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
OUTDIR="./backup"
mkdir -p "$OUTDIR"

podman exec postgres18 pg_dumpall -U "${POSTGRES_USER:-admin}" > "${OUTDIR}/pg_dumpall_${TS}.sql"
echo "Backup completed: ${OUTDIR}/pg_dumpall_${TS}.sql"
```

scripts/restore.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

SQL_FILE="${1:-}"
if [[ -z "$SQL_FILE" || ! -f "$SQL_FILE" ]]; then
  echo "Usage: $0 backup/pg_dumpall_YYYYMMDD_HHMMSS.sql" >&2
  exit 1
fi

podman exec -i postgres18 psql -U "${POSTGRES_USER:-admin}" -f - < "$SQL_FILE"
echo "Restore completed from $SQL_FILE"
```

🔄 7. 升級機制

7.1 小版號升級（18.0 → 18.3）

```bash
# 修改 .env
POSTGRES_TAG=18.3

# 執行升級腳本
./scripts/upgrade_minor.sh
```

scripts/upgrade_minor.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

./scripts/backup.sh

source .env
echo "Pulling postgres:${POSTGRES_TAG}"
podman pull docker.io/library/postgres:${POSTGRES_TAG}

podman-compose --env-file .env down
podman-compose --env-file .env up -d

sleep 5
podman ps
podman logs --tail=100 postgres18
echo "Minor upgrade to ${POSTGRES_TAG} completed."
```

7.2 大版號升級（18 → 19）

提供兩種方式：

A. 離線快速升級（pg_upgrade）

scripts/upgrade_major_pgupgrade.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

OLD_TAG="18.3"
NEW_TAG="19.1"
OLD_VOL="pgdata18"
NEW_VOL="pgdata19"

./scripts/backup.sh

podman pull docker.io/library/postgres:${OLD_TAG}
podman pull docker.io/library/postgres:${NEW_TAG}
podman pull docker.io/tianon/pg-upgrade:latest

podman-compose --env-file .env down
podman volume create ${NEW_VOL}

podman run --rm \
  -v ${OLD_VOL}:/var/lib/postgresql/old:Z \
  -v ${NEW_VOL}:/var/lib/postgresql/data:Z \
  -e PGUSER=${POSTGRES_USER:-admin} \
  -e POSTGRES_INITDB_ARGS="--data-checksums" \
  docker.io/tianon/pg-upgrade:latest \
  --old-bindir=/usr/lib/postgresql/${OLD_TAG%.*}/bin \
  --new-bindir=/usr/lib/postgresql/${NEW_TAG%.*}/bin

sed -i "s/^POSTGRES_TAG=.*/POSTGRES_TAG=${NEW_TAG}/" .env
sed -i "s/^PGDATA_VOLUME=.*/PGDATA_VOLUME=${NEW_VOL}/" .env

podman-compose --env-file .env up -d
echo "Major upgrade completed: ${OLD_TAG} -> ${NEW_TAG}"
```

B. 邏輯複寫升級（幾乎無停機）

scripts/upgrade_major_logical.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# 在舊叢集 (18) 執行：
# CREATE ROLE repl WITH REPLICATION LOGIN PASSWORD 'xxx';
# ALTER SYSTEM SET wal_level = logical;
# SELECT pg_reload_conf();
# CREATE PUBLICATION pub_all FOR ALL TABLES;

# 在新叢集 (19) 執行：
# CREATE SUBSCRIPTION sub_all
# CONNECTION 'host=OLD_HOST port=5432 dbname=coredb user=repl password=xxx'
# PUBLICATION pub_all WITH (copy_data = true);

# 同步完成後：
# 1. 停止應用寫入
# 2. 等待延遲歸零
# 3. 切換到新叢集
echo "Follow the inline SQL comments to perform logical replication upgrade."
```
