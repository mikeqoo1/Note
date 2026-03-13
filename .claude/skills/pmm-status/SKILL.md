---
name: pmm-status
description: 檢查 PMM 監控狀態，列出所有已註冊的服務和 agent 狀態
---

## 任務

檢查當前主機的 PMM Client 狀態，包含：

1. **PMM Client 容器狀態**
2. **pmm-agent 連線狀態**
3. **已註冊的服務列表**
4. **各 exporter 運行狀態**

## 執行步驟

1. 先偵測 pmm-agent listen port：
```bash
PMM_PORT=$(sudo docker exec pmm-client grep -oP 'listen-port:\s*\K\d+' /usr/local/percona/pmm/config/pmm-agent.yaml 2>/dev/null || echo "7777")
```

2. 查看 PMM Client 容器：
```bash
sudo docker ps --filter "name=pmm-client" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
```

3. 查看 pmm-admin status：
```bash
sudo docker exec pmm-client pmm-admin status --pmm-agent-listen-port=$PMM_PORT
```

4. 列出已註冊服務：
```bash
sudo docker exec pmm-client pmm-admin list --pmm-agent-listen-port=$PMM_PORT
```

5. 檢查 exporter 容器（如果有 MSSQL exporter）：
```bash
sudo docker ps --filter "name=mssql-exporter" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## 輸出格式

用表格整理結果，標示每個服務的健康狀態（Running/Down/Unknown）。
如有異常，給出具體的排障建議。
