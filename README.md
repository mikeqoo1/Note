# Note 筆記庫

> 個人技術筆記與工作紀錄

---

## 資料庫 `databases/`

| 筆記 | 說明 |
|------|------|
| [MariaDB](databases/Mariadb.md) | MariaDB 安裝、設定、管理 |
| [MariaDB PAM 原始碼](databases/MariaDB_10.11.9的pam_user_map.c) | MariaDB 10.11.9 pam_user_map.c |
| [TiDB](databases/TiDB.md) | TiDB 分散式資料庫 |
| [TiFlash Topology](databases/TiFlash_topology.yaml) | TiFlash 拓撲設定 |
| [TiDM 任務配置](databases/TiDM任務配置.yaml) | TiDM 任務 YAML |
| [Redis](databases/Readis.md) | Redis 筆記 |
| [Elasticsearch](databases/Elastic.md) | ELK Stack 筆記 |
| [HP 3PAR](databases/HP3PAR.md) | HP 3PAR 儲存系統 |
| [Hadoop](databases/Hadoop.md) | Hadoop 大數據 |
| [PostgreSQL](databases/postgres/) | PostgreSQL 部署與設定 |

## Linux 系統 `linux/`

| 筆記 | 說明 |
|------|------|
| [Linux](linux/Linux.md) | Linux 常用指令與管理 |
| [RockyLinux dracut bug](linux/RockyLinux%28dracut_bug%29.md) | RockyLinux dracut 問題紀錄 |
| [IO 模型](linux/IO模型.md) | IO 模型介紹與圖解 |
| [鎖的介紹](linux/鎖的介紹.md) | Lock 機制說明 |

## 資安 `security/`

| 筆記 | 說明 |
|------|------|
| [Hacker](security/Hacker.md) | 滲透測試與資安筆記 |
| [hacker.sh](security/hacker.sh) | 資安腳本 |
| [CheckList](security/CheckList.md) | 安全檢查清單 |
| [Lynis](security/Lynis.md) | Lynis 資安掃描工具 |
| [Lynis 報告](security/Lynis/) | Lynis 掃描結果 |

## 容器與自動化 `devops/`

| 筆記 | 說明 |
|------|------|
| [Docker](devops/Docker.md) | Docker 使用筆記 |
| [Podman](devops/podman.md) | Podman 容器管理 |
| [Ansible](devops/ansible.md) | Ansible 自動化 |
| [Foreman](devops/Foreman/) | Foreman 主機管理 |
| [PMM](devops/PMM/) | Percona Monitoring and Management |
| [Podman Demo](devops/podman_demo/) | Podman compose 範例 |
| [Docker 搬移腳本](devops/move_docker_volumes_to_data.sh) | Docker volumes 搬移到 /data |

## Git 與 CI/CD `git-cicd/`

| 筆記 | 說明 |
|------|------|
| [Git](git-cicd/Git.md) | Git 操作筆記 |
| [GitLab](git-cicd/Gitlab.md) | GitLab 設定與管理 |
| [SonarQube](git-cicd/SonarQube.md) | SonarQube 程式碼品質檢測 |
| [Nexus Repository](git-cicd/NexusRepositoryOSS.md) | Nexus 私有套件庫 |
| [Nexus 安裝腳本](git-cicd/Nexus.sh) | Nexus 部署腳本 |
| [OneDev 安裝腳本](git-cicd/OneDev.sh) | OneDev 部署腳本 |
| [Verdaccio](git-cicd/verdaccio.md) | Verdaccio npm 私有庫 |

## 網路與通訊 `networking/`

| 筆記 | 說明 |
|------|------|
| [WebRTC](networking/WebRTC.md) | WebRTC 串流技術 |
| [視訊文件](networking/視訊文件.md) | 視訊專案架構文件 |
| [uNetworking](networking/uNetworking/) | uWebSockets HTTP/3 建置 |
| [伺服器 192.168.199.133](networking/192.168.199.133.md) | 伺服器設定紀錄 |
| [HAProxy 設定](networking/haproxy-emst.cfg) | HAProxy 設定檔 |

## 硬體 `hardware/`

| 筆記 | 說明 |
|------|------|
| [Intel VROC](hardware/Intel.md) | Intel VROC RAID 設定 |
| [Intel 文件](hardware/Intel/) | Intel PDF 手冊與截圖 |
| [Raspberry Pi](hardware/RaspberryPi.md) | 樹莓派筆記 |

## 專案部署 `projects/`

| 筆記 | 說明 |
|------|------|
| [AI 終端機](projects/AI終端機/) | AI Workbench 部署 |
| [Plane Community](projects/plane_community/) | Plane 專案管理工具部署 |
| [Worklenz](projects/worklenz/) | Worklenz 專案管理工具 |

## 工具腳本 `scripts/`

| 筆記 | 說明 |
|------|------|
| [其他開發筆記](scripts/Other.md) | Node.js、Java、Golang、Clang 等雜記 |
| [空間清理](scripts/space-cleaner.sh) | 磁碟空間清理腳本 |
| [磁碟告警](scripts/sst.sh) | 磁碟空間告警通知 |
| [Task YAML](scripts/task234.yaml) | 任務設定範例 |

## 工作相關 `work/`

| 筆記 | 說明 |
|------|------|
| [健康專區](work/健康專區/) | 公司相關部署腳本與設定 |
| [打包大研究](work/打包大研究/) | 打包流程研究 |

## 個人 `personal/`

| 筆記 | 說明 |
|------|------|
| [我的塗鴉](personal/我的塗鴉/) | 手繪作品集 |
| [宜蘭民宿](personal/宜蘭民宿.md) | 宜蘭民宿筆記 |

---

### Git SSH 設定

```bash
# 產生 SSH key
ssh-keygen -t rsa -b 4096 -C "你的信箱"
# 把 pub 的內容加到 GitHub SSH key 設定

# 多帳號設定
ssh-keygen -t ed25519 -f ~/.ssh/github_company -C "公司信箱"

# ~/.ssh/config
Host github-company
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_company
  IdentitiesOnly yes
```
