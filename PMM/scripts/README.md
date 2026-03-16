# PMM Scripts 使用指南

在一台乾淨的機器上，從零開始部署 PMM Client + Demo 資料庫的完整步驟。

---

## 前置需求

```bash
# 1. 確認 Docker 已安裝
docker --version

# 2. 如果沒有 Docker，安裝它（CentOS / Rocky / RHEL）
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker

# Ubuntu / Debian
# sudo apt-get update && sudo apt-get install -y docker.io
# sudo systemctl enable --now docker

# 3. 確認 Docker 正常運作
sudo docker ps
```

---

## 步驟一：取得腳本

把 `PMM/` 整個資料夾複製到目標機器上：

```bash
# 從你的 Git repo clone，或直接 scp
scp -r PMM/ user@target-host:~/PMM/

# 在目標機器上
cd ~/PMM
chmod +x pmm_client.sh pmm_server.sh scripts/*.sh
```

---

## 步驟二：部署 PMM Client

腳本會自動完成：檢查連線 → 檢查 port → setup → 啟動 agent。

```bash
# 基本用法（預設 PMM Server = 192.168.199.234:18443）
sudo bash pmm_client.sh

# 指定 PMM Server 位址與密碼
PMM_SERVER_ADDR="你的PMM_SERVER_IP:18443" \
PMM_PASS="你的密碼" \
sudo -E bash pmm_client.sh

# 如果 port 7777 被佔用（腳本會自動偵測並提示）
PMM_AGENT_LISTEN_PORT=17777 \
PMM_SERVER_ADDR="192.168.199.234:18443" \
PMM_PASS="Aa123456" \
sudo -E bash pmm_client.sh
```

### 可調整的環境變數

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `PMM_SERVER_ADDR` | `192.168.199.234:18443` | PMM Server 位址 |
| `PMM_USER` | `admin` | PMM Server 帳號 |
| `PMM_PASS` | `Aa123456` | PMM Server 密碼 |
| `CONTAINER_NAME` | `pmm-client` | PMM Client 容器名稱 |
| `NODE_NAME` | `$(hostname -s)` | 在 PMM 上顯示的節點名稱 |
| `PMM_AGENT_LISTEN_PORT` | `7777` | pmm-agent listen port（被佔用時需改） |

### 驗證

```bash
# 確認容器在跑
sudo docker ps | grep pmm-client

# 確認 PMM Client 狀態（注意 port）
sudo docker exec pmm-client pmm-admin status
# 如果改過 port：
sudo docker exec pmm-client pmm-admin status --pmm-agent-listen-port=17777
```

### 部署原理

腳本繞過 PMM 3 預設 entrypoint，分兩步執行：

```
[1/2] docker run --rm --entrypoint pmm-agent ... setup --config-file=... --listen-port=...
[2/2] docker run -d   --entrypoint pmm-agent ... run   --config-file=...
```

這樣避免了 PMM 3 entrypoint 的 setup 失敗問題（status check 404）。

---

## 步驟三：部署 Demo 資料庫（選用）

一鍵部署 MariaDB + PostgreSQL + MSSQL，每種都含 PMM 帳號 + Audit + 範例資料：

```bash
# 部署全部
sudo bash scripts/deploy-demo-dbs.sh

# 只部署某一種
sudo bash scripts/deploy-demo-dbs.sh mariadb
sudo bash scripts/deploy-demo-dbs.sh postgresql
sudo bash scripts/deploy-demo-dbs.sh mssql

# 清除全部 demo 資料庫
sudo bash scripts/deploy-demo-dbs.sh cleanup
```

### Demo 資料庫規格

| 資料庫 | 容器名稱 | Host Port | 容器內 Port | Demo DB | PMM 帳號 |
|--------|---------|-----------|------------|---------|---------|
| MariaDB | demo-mariadb | 3307 | 3306 | demo_shop (customers/products/orders) | pmm / PmmMaria!234 |
| PostgreSQL | demo-postgres | 5433 | 5432 | demo_shop (employees/projects/assignments) | pmm / PmmPostgres!234 |
| MSSQL | demo-mssql | 2433 | 1433 | demo_shop (departments/tickets) | pmm / Str0ng#Audit789! |

> **MSSQL Exporter 說明**：使用 `burningalchemist/sql_exporter`（Go-based），
> 預設 Port **9399**。原 `awaragi/prometheus-mssql-exporter`（Node.js/tedious）
> 因 TLS 與 MSSQL 2022 不相容已棄用。

### Audit 設定

| 資料庫 | Audit 方式 | Log 位置 |
|--------|-----------|---------|
| MariaDB | server_audit plugin | /var/lib/mysql/server_audit.log |
| PostgreSQL | pgaudit（如 image 支援）+ log_statement=ddl | Docker logs |
| MSSQL | SQL Server Audit | /var/opt/mssql/audit/*.sqlaudit |

### Port 說明

用容器 IP 連線時填**容器內部 port**，用 Host IP 連線時填**映射 port**：

| 連線方式 | Host | Port 範例（以 PG 為例） |
|---------|------|----------------------|
| 容器 IP（docker inspect 取得） | 172.18.0.x | **5432**（容器內部） |
| Host IP（127.0.0.1） | 127.0.0.1 | **5433**（映射 port） |

---

## 步驟四：把資料庫註冊到 PMM

### 方法 A：一鍵加入 Demo 資料庫（推薦）

```bash
sudo bash scripts/add-db.sh
# 選 d → 自動加入三種 Demo 資料庫，零輸入
```

腳本會自動：
1. 檢查三個 demo 容器是否運行中
2. 取得各容器 IP
3. 用 deploy-demo-dbs.sh 裡的帳密直接註冊
4. MSSQL 會自動啟動 exporter 容器

### 方法 B：互動式逐一加入

```bash
sudo bash scripts/add-db.sh
# 選 1/2/3 → 依提示輸入連線資訊
```

選單功能：

```
╔═══════════════════════════════════════╗
║      PMM 資料庫註冊管理工具           ║
╠═══════════════════════════════════════╣
║  d) 一鍵加入 Demo 資料庫（推薦）      ║
║  1) 新增 MySQL / MariaDB              ║
║  2) 新增 PostgreSQL                   ║
║  3) 新增 MSSQL                        ║
║  4) 列出已註冊服務                    ║
║  5) 移除服務                          ║
║  0) 離開                              ║
╚═══════════════════════════════════════╝
```

### 方法 C：手動指令

```bash
# 注意：如果 pmm-agent 不是跑在預設 port 7777，需要加 --pmm-agent-listen-port

# --- MariaDB ---
sudo docker exec pmm-client pmm-admin add mysql \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='PmmMaria!234' \
  --host=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' demo-mariadb) \
  --port=3306 \
  --service-name=demo-mariadb \
  --query-source=perfschema

# --- PostgreSQL ---
sudo docker exec pmm-client pmm-admin add postgresql \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='PmmPostgres!234' \
  --host=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' demo-postgres) \
  --port=5432 \
  --database=demo_shop \
  --service-name=demo-postgres \
  --query-source=pgstatements
```

---

## 步驟五：驗證

```bash
# 列出所有已註冊的服務
sudo docker exec pmm-client pmm-admin list --pmm-agent-listen-port=17777

# 打開 PMM Web UI 確認
# https://你的PMM_SERVER_IP:18443
# Dashboard → MySQL / PostgreSQL / Node Summary
```

---

## 完整流程摘要（一台乾淨機器 → 全部就緒）

```bash
cd ~/PMM

# 1. 部署 PMM Client（port 7777 被佔用的情況）
PMM_AGENT_LISTEN_PORT=17777 \
PMM_SERVER_ADDR="192.168.199.234:18443" \
PMM_PASS="Aa123456" \
sudo -E bash pmm_client.sh

# 2. 部署 Demo 資料庫
sudo bash scripts/deploy-demo-dbs.sh

# 3. 一鍵註冊（選 d）
sudo bash scripts/add-db.sh

# 4. 打開 PMM UI 確認 → https://192.168.199.234:18443
```

---

## 檔案說明

```
PMM/
├── pmm_server.sh              # 部署 PMM Server（Docker）
├── pmm_client.sh              # 部署 PMM Client（Docker，繞過 entrypoint）
├── mssql.json                 # MSSQL Grafana Dashboard（手動 Import）
├── audit-log-dashboard.json   # DB Audit Log Dashboard（Loki，手動 Import）
├── scripts/
│   ├── README.md              # 本文件
│   ├── deploy-demo-dbs.sh     # 一鍵部署三種 Demo DB（含帳號/Audit/範例資料）
│   ├── add-db.sh              # 互動式註冊 DB 到 PMM（含一鍵 Demo 模式）
│   ├── deploy-loki.sh         # 在 PMM Server 上部署 Loki（audit log 收集）
│   ├── deploy-promtail.sh     # 在 DB 主機上部署 Promtail（推送 log 到 Loki）
│   └── setup-db-audit.sh      # 在 DB 容器中啟用 audit log
```

---

## 步驟六（選用）：部署 Audit Log 收集（Loki + Promtail）

在 PMM Grafana 中查看資料庫 audit log，需要部署 Loki（集中 log 儲存）和 Promtail（log 收集）。

### 架構

```
DB 主機 (Promtail) ──push──> PMM Server (Loki) ──query──> Grafana
```

### 部署步驟

```bash
# 1. 在 PMM Server 主機 (234) 上部署 Loki
sudo bash scripts/deploy-loki.sh

# 2. 在各 DB 主機上啟用 audit log
sudo bash scripts/setup-db-audit.sh
# 選 d → Demo 環境一鍵設定

# 3. 在各 DB 主機上部署 Promtail
sudo bash scripts/deploy-promtail.sh http://192.168.199.234:3100

# 4. 在 PMM Grafana 中 Import audit-log-dashboard.json
#    或到 Explore → 選 Loki datasource → 查詢:
#    {job="db-audit"}
```

### Audit Log 類型

| 資料庫 | Audit 機制 | 收集方式 |
|--------|-----------|---------|
| MariaDB | server_audit plugin | Docker container logs → Promtail |
| PostgreSQL | pgaudit extension | Docker container logs → Promtail |
| MSSQL | SQL Server Audit (.sqlaudit) | 需定期轉文字 → Promtail |

> **MSSQL 注意**：SQL Server Audit 產生的是二進位 `.sqlaudit` 檔案，
> 需要用 `sys.fn_get_audit_file()` 轉換。`setup-db-audit.sh` 會建立轉換腳本，
> 設定 cron job 定期匯出即可。

---

## 常見問題

### PMM Client 連不上 Server

```bash
# 檢查網路
curl -kI https://PMM_SERVER_IP:18443

# 檢查防火牆
sudo firewall-cmd --list-ports
# 需要開放: 18443/tcp（或你用的 port）
```

### Port 7777 被佔用

腳本會自動偵測並報錯，改用其他 port 即可：

```bash
PMM_AGENT_LISTEN_PORT=17777 sudo -E bash pmm_client.sh
```

之後所有 `pmm-admin` 指令都要加 `--pmm-agent-listen-port=17777`，
使用 `add-db.sh` 時會自動偵測，不需要手動加。

### pmm-admin 指令回傳 404

```
Failed to get PMM Server parameters from local pmm-agent: [POST /local/Status][404]
```

原因：pmm-agent 不在預設 port 7777，加上 `--pmm-agent-listen-port=你的port`。

### docker inspect 拿不到 IP

容器可能不在 Docker network 上：

```bash
sudo docker network ls
sudo docker network inspect pmm-net

# 讓容器加入 network
sudo docker network connect pmm-net demo-mariadb
```

### MSSQL 啟動很慢

MSSQL 首次啟動需要 30-90 秒，腳本已內建等待機制（最多等 90 秒）。

### 帳號建立失敗（Access denied）

如果用 `deploy-demo-dbs.sh` 建立的資料庫，帳號已經建好了，
在 `add-db.sh` 互動模式中「是否建立 PMM 帳號」選 **N** 即可。
或直接選 **d**（一鍵 Demo 模式）跳過所有輸入。
