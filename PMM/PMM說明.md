# PMM（Percona Monitoring and Management）官方文件簡易說明（PMM 3）

> 目標：讓第一次接觸的人，10 分鐘內知道 **PMM 是什麼 / 能做什麼 / 怎麼部署與開始監控**。

---

## 0. PMM 是什麼？你會用它來做什麼？

PMM 是 Percona 提供的 **資料庫可觀測性（Observability）與效能監控平台**。  
它不是單純的 uptime 監控，而是專門用來看：

- 主機 CPU / RAM / Disk / IO
- 資料庫效能（MySQL / MariaDB / PostgreSQL / MongoDB / Redis / Valkey…）
- SQL Query 執行時間、次數、慢查詢
- 鎖、索引使用率、InnoDB 指標、Replication 狀態…  

一句話：  
> **PMM = Infra + Database 專家級監控平台（不是一般 APM）**

---

## 1. 架構總覽（一定要先懂）

PMM 架構永遠是這樣：

```
[ 被監控主機 / DB Server ]
        |
     PMM Client
   (pmm-agent)
        |
        v
[     PMM Server     ]
   Web UI + Storage
```

- **PMM Server**：中央伺服器，提供 Web UI、儲存與分析資料
- **PMM Client**：裝在每一台要被監控的主機上，負責收集資料並送回 Server

👉 重點：  
**一台主機只需要裝一個 PMM Client，不是每個 container 裝一個。**

---

## 2. 有哪些套件？各自做什麼？

### 2.1 核心元件

| 元件 | 角色 | 功能 |
|------|------|------|
| **PMM Server** | 中央伺服器 | Web UI、Dashboard、Query Analytics、儲存 metrics |
| **PMM Client** | 代理程式 | 裝在被監控主機上，收集系統與 DB 指標 |
| **pmm-agent** | Daemon | PMM Client 的核心服務，負責管理 exporters |
| **pmm-admin** | CLI 工具 | 用來註冊主機、加入資料庫服務 |

---

### 2.2 PMM 能監控什麼？

PMM 原生支援：

- MySQL / MariaDB
- PostgreSQL
- MongoDB
- Redis / Valkey
- HAProxy
- ProxySQL
- OS 主機資源（CPU / RAM / Disk / Network）

---

## 3. Port 與網路需求（實務最常卡關的地方）

### 3.1 一定要開的

| Port | 方向 | 用途 |
|------|------|------|
| **443/TCP** | Client → Server | HTTPS + gRPC（主要通道，必開） |
| 80/TCP | Client → Server | HTTP（不建議，用測試） |

👉 **正式環境請只開 443**

---

### 3.2 內部用（若有防火牆 / ACL 需注意）

| Port | 用途 |
|------|------|
| 7771 | pmm-agent ↔ PMM Server gRPC |
| 8428 | VictoriaMetrics（時序資料） |
| 42000–51999 | pmm-agent 連 exporters 預設範圍 |

> 如果你環境防火牆很嚴，這段一定要看，不然會出現「加了服務但沒資料」

---

## 4. 官方建議的部署方式

### 4.1 PMM Server 部署方式

| 方式 | 適合情境 |
|------|----------|
| **Docker** | 最推薦，適合 90% 情境 |
| Podman (rootless) | 高安全要求環境 |
| Helm (K8s) | 大型 / 雲原生 |
| Virtual Appliance (OVA) | 傳統 VM 環境 |
| AWS Marketplace | 全 AWS 架構 |

👉 官方 **最推薦 Docker**，文件與支援也最完整

---

### 4.2 PMM Client 部署方式

| 方法 | 最適合 | 優點 | 注意事項 |
|---|---|---|---|
| **Package Manager（rpm/deb）** | 支援的 Linux 正式環境 | 安裝與維護最順、跟 OS 整合 | 需要 repo/套件來源可用 |
| **Binary package** | 不支援 distro / 想 non-root 或隔離環境 | 可攜、依賴少 | 更新需手動、流程更偏手工 |
| **Docker** | 容器化主機或測試 | 環境一致、好搬移 | 仍要取得 host metrics 的能力（容器權限/掛載） |

---

### 4.3 官方推薦組合（照規模）

官方給了一個很實用的規模建議：

- **小型（1–30 台）**：Server 用 **Docker 或 Virtual Appliance**；Client 用 **Package Manager**
- **中型（31–200）**：Server 用 **Docker（建議用 volume）或 Kubernetes**；Client 用 **Package Manager 或 Docker**  
- **大型（200+）**：Server 用 **Kubernetes**；Client 用 **Package Manager 自動化佈署**  
- **雲資料庫監控**：搭配 **PMM Remote** + cloud 方式（RDS/Azure/Cloud SQL 等）:

---

## 5. 最快部署方式（官方 Quickstart）

### 5.1 一行指令啟動 PMM Server（Docker）

```bash
curl -fsSL https://raw.githubusercontent.com/percona/pmm/refs/heads/v3/get-pmm.sh | /bin/bash
```

或

```bash
wget -qO - https://raw.githubusercontent.com/percona/pmm/refs/heads/v3/get-pmm.sh | /bin/bash
```

完成後：

```
https://<你的主機IP>
帳號：admin
密碼：admin
```

👉 **第一件事：改密碼**

---

## 6. 安裝 PMM Client（被監控主機）

```bash
sudo dnf install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm
sudo percona-release enable pmm3-client
sudo dnf install -y pmm-client
```

```bash
sudo pmm-admin config --server-insecure-tls --server-url=https://admin:admin@PMM_SERVER_IP
```

---

## 7. 加入資料庫監控

```bash
pmm-admin add mysql --username=root --password=xxx --host=127.0.0.1 --port=3306
pmm-admin add postgresql --username=postgres --password=xxx --host=127.0.0.1 --port=5432
pmm-admin add redis --host=127.0.0.1 --port=6379
```

---

## 8. 官方推薦流程（濃縮版）

1. 架 PMM Server  
2. 每台主機裝 PMM Client  
3. 用 `pmm-admin add xxx` 加入資料庫  
4. 打開 Web UI 看 Dashboard  

---

## 9. 給完全不懂的人一句話版本

> **PMM 就是一個「專門監控資料庫的 Grafana + 專家分析工具」  
> 架一台 Server，其他機器裝 Client，就開始有圖表。**
