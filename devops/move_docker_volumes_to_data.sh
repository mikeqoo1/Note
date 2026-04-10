#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 將 Docker 的 data-root 從 /var/lib/docker 移到 /data/docker
#
# 這支腳本會做：
# 1. 檢查是否 root
# 2. 停止 docker / containerd
# 3. 使用 rsync 將 /var/lib/docker 搬到 /data/docker
# 4. 設定 /etc/docker/daemon.json 指向新的 data-root
# 5. 啟動 docker 並驗證
#
# 適合情境：
# - /var (系統碟) 快爆了
# - /data 是掛在大顆硬碟
# - 想一次把 image / volumes / overlay2 全搬走
###############################################################################

NEW_ROOT="/data/docker"
OLD_ROOT="/var/lib/docker"
DAEMON_JSON="/etc/docker/daemon.json"
TS="$(date +%F_%H%M%S)"
BACKUP_DAEMON_JSON="${DAEMON_JSON}.bak.${TS}"

# ===== 小工具函式 =====

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "❌ 錯誤：請用 root 或 sudo 執行此腳本" >&2
    exit 1
  fi
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

info() {
  echo -e "\n\033[1;34m==> $*\033[0m"
}

# ===== 開始檢查 =====

need_root

for c in rsync systemctl docker; do
  if ! cmd_exists "$c"; then
    echo "❌ 錯誤：系統缺少指令 $c，請先安裝" >&2
    exit 1
  fi
done

info "檢查 /data 是否存在，以及磁碟空間"
if [[ ! -d /data ]]; then
  echo "❌ 錯誤：/data 不存在，請先把大顆硬碟掛到 /data" >&2
  exit 1
fi

df -h /data || true

info "建立新 Docker 目錄：${NEW_ROOT}"
mkdir -p "${NEW_ROOT}"

# ===== 停止服務 =====

info "停止 Docker 服務"
systemctl stop docker || true
systemctl stop containerd 2>/dev/null || true

info "確認 dockerd 已停止"
if pgrep -x dockerd >/dev/null 2>&1; then
  echo "❌ 錯誤：dockerd 仍在執行中，請先停止再重試" >&2
  exit 1
fi

# ===== 搬資料 =====

info "開始搬移資料：${OLD_ROOT}  →  ${NEW_ROOT}"
info "（這一步會花一點時間，請耐心等）"

rsync -aHAX --numeric-ids "${OLD_ROOT}/" "${NEW_ROOT}/"

info "資料同步完成"

# ===== 設定 daemon.json =====

info "備份原本的 ${DAEMON_JSON}（如果存在）"
mkdir -p "$(dirname "${DAEMON_JSON}")"
if [[ -f "${DAEMON_JSON}" ]]; then
  cp -a "${DAEMON_JSON}" "${BACKUP_DAEMON_JSON}"
  echo "已備份：${BACKUP_DAEMON_JSON}"
fi

info "寫入新的 ${DAEMON_JSON}，指定 data-root=${NEW_ROOT}"

cat > "${DAEMON_JSON}" <<JSON
{
  "data-root": "${NEW_ROOT}"
}
JSON

# ===== 啟動 Docker =====

info "重新載入 systemd 設定"
systemctl daemon-reload || true

info "啟動 Docker"
systemctl start docker

# ===== 驗證 =====

info "驗證 Docker Root 目錄是否正確"
docker info 2>/dev/null | grep -E "Docker Root Dir|Server Version" || true

info "簡單測試 docker 是否正常"
docker ps >/dev/null
docker volume ls >/dev/null

# ===== 完成訊息 =====

cat <<'TXT'

🎉 完成！Docker data-root 已移到 /data/docker

【接下來請務必做的事】
1) 檢查你的服務是否正常：
   - docker ps
   - docker compose up -d
   - Plane / PMM / 其他服務是否都能起來

2) 確定「完全正常」後，再清掉舊資料釋放空間：
   建議先改名備份：
     sudo mv /var/lib/docker /var/lib/docker.bak.$(date +%F)
   觀察 1~2 天沒問題再刪：
     sudo rm -rf /var/lib/docker.bak.YYYY-MM-DD

【回復原狀（Rollback）方式】
如果哪裡怪怪的：

1) 停止 Docker
   sudo systemctl stop docker

2) 還原 daemon.json
   sudo cp -a /etc/docker/daemon.json.bak.<時間戳> /etc/docker/daemon.json
   或直接編輯 /etc/docker/daemon.json 移除 data-root

3) 啟動 Docker
   sudo systemctl start docker

備註：
- 如果你系統有開 SELinux，遇到權限錯誤再跟我說，我教你補 context
- 如果 /data 是 NFS 或網路碟，也要跟我說，那處理方式不同

TXT

