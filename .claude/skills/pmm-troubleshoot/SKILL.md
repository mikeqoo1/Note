---
name: pmm-troubleshoot
description: PMM 監控問題排障。診斷連線問題、exporter 異常、Dashboard 無資料等。
---

## 任務

根據使用者描述的問題，系統性排障 PMM 監控問題。

## 排障流程

### 1. 基礎檢查
```bash
# PMM Client 容器是否在跑
sudo docker ps | grep pmm-client

# pmm-agent 狀態
PMM_PORT=$(sudo docker exec pmm-client grep -oP 'listen-port:\s*\K\d+' /usr/local/percona/pmm/config/pmm-agent.yaml 2>/dev/null || echo "7777")
sudo docker exec pmm-client pmm-admin status --pmm-agent-listen-port=$PMM_PORT

# 列出所有服務
sudo docker exec pmm-client pmm-admin list --pmm-agent-listen-port=$PMM_PORT
```

### 2. 常見問題對照表

| 症狀 | 原因 | 解法 |
|------|------|------|
| `[404] Status default` | pmm-agent port 不對 | 加 `--pmm-agent-listen-port=17777` |
| `Connection refused` | PMM Server 不可達 | 檢查 `curl -kI https://PMM_SERVER:18443` |
| `Access denied` | DB 帳號權限不足 | 建立 PMM 監控帳號 |
| Dashboard 顯示 No data | label 不匹配或剛註冊 | 檢查 Explore 頁面的 metric label |
| MSSQL exporter socket hang up | awaragi image TLS 問題 | 改用 `burningalchemist/sql_exporter` |
| MSSQL Login failed | 帳號被鎖或密碼錯 | `CHECK_POLICY=OFF` 重建帳號 |
| exporter 狀態 Unknown | 正常（external exporter 預設狀態） | 確認 metrics endpoint 有回應即可 |

### 3. 進階診斷
```bash
# 查看 PMM Client logs
sudo docker logs pmm-client --tail 50

# 查看特定 exporter logs
sudo docker logs demo-mssql-exporter --tail 20

# 測試 metrics endpoint
curl -s http://127.0.0.1:9399/metrics | head -10   # MSSQL
curl -s http://127.0.0.1:42004/metrics | head -10   # mysqld_exporter

# 檢查容器網路
sudo docker network inspect pmm-net

# PMM Server 健康檢查
curl -kI https://192.168.199.234:18443
```

### 4. 重啟順序（最後手段）
```bash
# 先重啟有問題的 exporter
sudo docker restart demo-mssql-exporter

# 如果還不行，重啟 PMM Client
sudo docker restart pmm-client

# 最後才考慮重啟 PMM Server（影響所有監控）
# sudo docker restart pmm-server
```

## 注意事項
- 不要隨意 `docker rm` 容器，先確認原因
- PMM Server 重啟會影響所有主機的監控，謹慎操作
- 排障時先看 logs，不要盲目重啟
