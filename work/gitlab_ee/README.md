# GitLab EE on Docker 部署

官方 omnibus 映像（`gitlab/gitlab-ee`）的 docker compose 部署，含部署／備份／還原／升級腳本。

> 與 192.168.199.235 上既有的 `sameersbn/gitlab`（CE）**不是同一套**：
> 官方映像用 `gitlab-ctl` / `gitlab-rails` / `gitlab-backup` 指令，設定走 `GITLAB_OMNIBUS_CONFIG`（gitlab.rb 語法）。
> EE 映像沒灌 license 時等同 Free 功能，之後要啟用付費功能到 Admin Area → Subscription 上傳 license 即可，不用換映像。

## 目錄結構

```
gitlab_ee/
├── README.md
├── .env.example          # 參數範本（複製成 .env 修改，.env 不進 git）
├── docker-compose.yml
└── scripts/
    ├── deploy.sh         # 首次部署 + 等 healthy + 印初始 root 密碼
    ├── backup.sh         # gitlab-backup + secrets 備份 + 清舊檔（可排 cron）
    ├── restore.sh        # 從備份還原（互動確認）
    └── upgrade.sh        # 升級（自動先備份、檢查 background migration）
```

## 快速開始

```bash
cp .env.example .env
vim .env                  # 至少改 EXTERNAL_URL、GITLAB_HOME、版本
./scripts/deploy.sh       # 使用者不在 docker 群組時：sudo ./scripts/deploy.sh
```

首次初始化約 5-10 分鐘。完成後用 `root` + 腳本印出的初始密碼登入（該密碼檔 24 小時後自動刪除，請立即改密碼）。

## 埠號設計

| 用途 | Host 埠（預設） | 容器埠 |
|------|----------------|--------|
| HTTP | 30080 | 80 |
| HTTPS | 30443 | 443 |
| Git SSH | 30022 | 22 |

有個 omnibus 的坑：`external_url` 帶非標準埠（如 `:30080`）時，omnibus 預設會把容器內 nginx 監聽埠也改成 30080，導致 `30080:80` 的埠對映失效。compose 裡已用 `nginx['listen_port']` 把容器內埠釘死，`.env` 的 `NGINX_INTERNAL_PORT` 維持 80（HTTPS 模式改 443）即可。

clone 位址的 SSH 埠會自動顯示為 `GITLAB_SSH_PORT`（已設 `gitlab_shell_ssh_port`）。

## 切換 HTTPS（自簽憑證）

1. 產生憑證，檔名必須是 `<GITLAB_HOSTNAME>.crt` / `.key`：

   ```bash
   mkdir -p ${GITLAB_HOME}/config/ssl
   openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
     -keyout ${GITLAB_HOME}/config/ssl/gitlab.concords.com.tw.key \
     -out   ${GITLAB_HOME}/config/ssl/gitlab.concords.com.tw.crt \
     -subj "/CN=gitlab.concords.com.tw" \
     -addext "subjectAltName=DNS:gitlab.concords.com.tw,IP:<主機IP>"
   ```

2. `.env` 改三個值：

   ```
   EXTERNAL_URL=https://<主機IP或域名>:30443
   NGINX_INTERNAL_PORT=443
   ```

3. `docker compose up -d` 讓 omnibus reconfigure。

注意：官方映像 `external_url` 是 https 時預設會開 Let's Encrypt，內網拿不到憑證會 reconfigure 失敗；若遇到，在 compose 的 `GITLAB_OMNIBUS_CONFIG` 加一行 `letsencrypt['enable'] = false`。

## 備份 / 還原

```bash
./scripts/backup.sh                          # 手動備份
# cron 範例（每天 02:00）：
# 0 2 * * * cd /path/to/gitlab_ee && ./scripts/backup.sh >> /var/log/gitlab-backup.log 2>&1

./scripts/restore.sh <BACKUP_ID>             # 還原，BACKUP_ID 見 data/backups/ 檔名
```

**secrets 是命門**：`gitlab-backup` 的 tar **不包含** `gitlab-secrets.json`。沒有它，還原後 CI/CD variables、2FA、runner token 全部解不開。`backup.sh` 會把它拷到 `SECRET_BACKUP_DIR`，建議再同步到別台主機。

還原前提：容器版本必須與備份時完全一致（tar 檔名帶版本號，先 `upgrade.sh`/降版對齊再還原）。

## 升級

```bash
./scripts/upgrade.sh 19.3.0-ee.0
```

- **不可跳版**：先查 [官方升級路徑](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path/)，跨版要逐站停靠。
- 腳本會自動：先備份 → 確認 background migrations 歸零 → 改 `.env` → 重建 → 等 healthy。
- 升級後 background migrations 會在背景繼續跑一陣子（Admin Area → Monitoring → Background migrations 可看進度），**跑完前不要再升下一版**。

## Healthcheck / 監控

- compose 用官方 `/opt/gitlab/bin/gitlab-healthcheck`，它會照 gitlab.rb 產生的 scheme/埠打 liveness，不會踩「寫死 http 被 301 轉 https 而永遠 unhealthy」的坑（199.235 那台 sameersbn 踩過）。
- `/-/liveness`、`/-/readiness` 預設只允許容器內 127.0.0.1 存取，**從外部打會 404**；外部監控（PMM/uptime）請改打 `/users/sign_in` 判 200。
- 重建／重啟後完整開機約 5-10 分鐘（`start_period` 已設 10m）。

## 常用指令

```bash
docker compose logs -f gitlab                          # 看啟動日誌
docker compose exec gitlab gitlab-ctl status           # 各元件狀態
docker compose exec gitlab gitlab-ctl tail nginx       # 追特定元件 log
docker compose exec gitlab gitlab-rake gitlab:check SANITIZE=true   # 健檢
docker compose exec gitlab gitlab-rails console        # rails console（省著用，見下）
```

**rails console/runner 要節制**：每開一次就是一整個 Rails 連線池，連跑幾次會把內建 Postgres 連線打爆（199.235 出過事）。需要批次操作先建短效 PAT 走 REST API。

## 寄信測試

```bash
docker compose exec gitlab gitlab-rails runner \
  "Notify.test_email('你的信箱@concords.com.tw', '測試主旨', '測試內文').deliver_now"
```

SMTP 走 `mailgw.concords.com.tw:25`（內網免認證、STARTTLS、verify_mode=none），與 199.235 那台同設定。
