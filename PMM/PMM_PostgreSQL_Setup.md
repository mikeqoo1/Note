
# PMM + PostgreSQL 設定指南（實戰可照抄版）

本文件說明如何正確設定 **Percona Monitoring and Management (PMM)** 監控 **PostgreSQL**，
並明確區分 **Container 版** 與 **實體（Host）版** PostgreSQL。

---

## 核心觀念（一定要先看）

- PMM 監控的是 **PostgreSQL instance（整個服務）**，不是單一 database  
- Query Analytics (QAN) 依賴：
  - `pg_stat_statements`
  - 必須在 PostgreSQL 啟動時透過 `shared_preload_libraries` preload
- 只有 `CREATE EXTENSION` **不夠**，一定要 preload + restart

---

# 一、Container 版 PostgreSQL（Docker / Podman）

適用情境：
- PostgreSQL 跑在 container 內

---

## 1. 建立 PMM 監控帳號

```bash
docker exec -it <pg_container> psql -U <superuser> -d postgres
```

```sql
CREATE USER pmm WITH PASSWORD 'StrongPMMpass!';
GRANT pg_monitor TO pmm;
GRANT pg_read_all_stats TO pmm;
```

---

## 2. 啟用 pg_stat_statements（關鍵步驟）

### 2.1 設定 preload

```bash
docker exec -it <pg_container> \
  psql -U <superuser> -d postgres \
  -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';"
```

建議一併設定：

```bash
docker exec -it <pg_container> \
  psql -U <superuser> -d postgres \
  -c "ALTER SYSTEM SET pg_stat_statements.track = 'all';"
```

---

### 2.2 重啟 PostgreSQL container（不可省）

```bash
docker restart <pg_container>
```

---

## 3. 建立 extension（至少兩個 DB）

```bash
# APP DB
docker exec -it <pg_container> \
  psql -U <superuser> -d <app_db> \
  -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# postgres DB
docker exec -it <pg_container> \
  psql -U <superuser> -d postgres \
  -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

---

## 4. 驗證

```bash
docker exec -it <pg_container> \
  psql -U pmm -d postgres \
  -c "SHOW shared_preload_libraries;"

docker exec -it <pg_container> \
  psql -U pmm -d postgres \
  -c "SELECT count(*) FROM pg_stat_statements;"
```

---

## 5. 加入 PMM（Container PostgreSQL）

### 取得 container IP

```bash
docker inspect <pg_container> \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

### pmm-admin

```bash
sudo pmm-admin add postgresql \
  --server-url=https://admin:<PMM_PASS>@<PMM_SERVER>:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=<CONTAINER_IP> \
  --port=5432 \
  --service-name=postgres-<service-name>
```

---

# 二、實體（Host）版 PostgreSQL

適用：
- Rocky / RHEL / Ubuntu
- PostgreSQL 以 systemd 管理

---

## 1. 建立 PMM 帳號

```bash
sudo -u postgres psql
```

```sql
CREATE USER pmm WITH PASSWORD 'StrongPMMpass!';
GRANT pg_monitor TO pmm;
GRANT pg_read_all_stats TO pmm;
```

---

## 2. 啟用 pg_stat_statements

編輯 `postgresql.conf`：

```conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
```

---

## 3. 重啟 PostgreSQL

```bash
sudo systemctl restart postgresql
```

---

## 4. 建立 extension

```bash
sudo -u postgres psql -d postgres \
  -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

sudo -u postgres psql -d <app_db> \
  -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

---

## 5. 加入 PMM（Host PostgreSQL）

```bash
sudo pmm-admin add postgresql \
  --server-url=https://admin:<PMM_PASS>@<PMM_SERVER>:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=127.0.0.1 \
  --port=5432 \
  --service-name=postgres-host
```

---

## 常見錯誤速查

| 錯誤 | 原因 | 解法 |
|----|----|----|
| pgstatements Waiting | 沒 preload | 設定 + restart |
| must be loaded via shared_preload_libraries | 只建 extension | preload + restart |
| relation does not exist | DB 沒建 extension | CREATE EXTENSION |
| 沒 QAN | pmm 權限不足 | GRANT pg_monitor |

---

## 總結

> **preload + restart + extension + 權限**  
> 四件事齊全，PMM + PostgreSQL 就一定正常。
