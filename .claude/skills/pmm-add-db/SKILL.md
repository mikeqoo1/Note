---
name: pmm-add-db
description: 將資料庫新增到 PMM 監控。支援 MySQL/MariaDB、PostgreSQL、MSSQL。
---

## 任務

引導使用者將資料庫加入 PMM 監控。

## 使用方式

直接使用現有腳本（推薦）：
```bash
sudo bash PMM/scripts/add-db.sh
```

如果是 Demo 環境（用 deploy-demo-dbs.sh 建立的），選 `d` 一鍵加入。

## 手動加入指南

先偵測 pmm-agent port：
```bash
PMM_PORT=$(sudo docker exec pmm-client grep -oP 'listen-port:\s*\K\d+' /usr/local/percona/pmm/config/pmm-agent.yaml 2>/dev/null || echo "7777")
```

### MySQL / MariaDB
```bash
sudo docker exec pmm-client pmm-admin add mysql \
  --pmm-agent-listen-port=$PMM_PORT \
  --username=pmm \
  --password='密碼' \
  --host=容器IP \
  --port=3306 \
  --service-name=服務名稱 \
  --query-source=perfschema
```

### PostgreSQL
```bash
sudo docker exec pmm-client pmm-admin add postgresql \
  --pmm-agent-listen-port=$PMM_PORT \
  --username=pmm \
  --password='密碼' \
  --host=容器IP \
  --port=5432 \
  --database=資料庫名 \
  --service-name=服務名稱 \
  --query-source=pgstatements
```

### MSSQL
MSSQL 使用 `burningalchemist/sql_exporter`（Go-based），步驟較多：
1. 建立 sql_exporter YAML config + collector
2. 啟動 sql_exporter 容器（port 9399）
3. 用 `pmm-admin add external` 註冊

推薦使用 `add-db.sh` 腳本的選項 3 或 d 來自動處理。

## 常見問題

- **404 錯誤**: pmm-agent port 不對，加上 `--pmm-agent-listen-port`
- **Access denied**: 先建立 PMM 監控帳號
- **Port 混淆**: 容器 IP 用容器內部 port（3306/5432），Host IP 用映射 port
