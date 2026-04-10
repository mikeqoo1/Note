#!/usr/bin/env bash
set -euo pipefail

# =========================
#  Space Cleaner (Interactive)
#  Tested on RHEL/Rocky/Alma 9
# =========================

RED=$(printf '\033[31m'); GREEN=$(printf '\033[32m'); YELLOW=$(printf '\033[33m'); BLUE=$(printf '\033[34m'); RESET=$(printf '\033[0m')

confirm() {
  local prompt="${1:-Are you sure?} [y/N] "
  read -r -p "$prompt" ans || true
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

exists() { command -v "$1" >/dev/null 2>&1; }

size_of() {
  local path="$1"
  [[ -e "$path" ]] || { echo "0	$path"; return; }
  sudo du -sh "$path" 2>/dev/null || true
}

safe_rm_rf() {
  # sanity guard: refuse to delete critical roots
  for p in "$@"; do
    [[ -z "$p" ]] && { echo "${RED}[ERR] empty path in rm -rf${RESET}"; return 1; }
    [[ "$p" == "/" ]] && { echo "${RED}[ERR] refusing to delete /${RESET}"; return 1; }
    [[ "$p" == "/root" ]] && { echo "${YELLOW}[WARN] Not deleting /root blindly${RESET}"; return 1; }
  done
  sudo rm -rf "$@"
}

headline() {
  echo
  echo "${BLUE}==> $*${RESET}"
}

section_sizes() {
  headline "目前主要磁區佔用"
  size_of /opt/gitlab
  size_of /opt/gitlab/backups
  size_of /opt/gitlab/shared/artifacts
  size_of /opt/sonarqube/data
  size_of /var/lib/docker
  size_of /var/lib/containers
  size_of /var/lib/snapd
  size_of /tmp
  size_of /var/tmp
}

cleanup_tmp() {
  headline "清理 /tmp、/var/tmp"
  echo "Before:"
  size_of /tmp
  size_of /var/tmp
  if confirm "清理暫存檔案嗎？(/tmp, /var/tmp)"; then
    safe_rm_rf /tmp/* || true
    safe_rm_rf /var/tmp/* || true
    echo "After:"
    size_of /tmp
    size_of /var/tmp
    echo "${GREEN}✔ 暫存已清理${RESET}"
  else
    echo "${YELLOW}略過暫存清理${RESET}"
  fi
}

cleanup_docker() {
  if exists docker && sudo test -d /var/lib/docker; then
    headline "Docker 清理（未使用的 images/containers/volumes/build cache）"
    echo "Before:"
    size_of /var/lib/docker
    docker system df || true
    if confirm "執行 docker system prune -a -f 與 docker volume prune -f？"; then
      sudo docker system prune -af || true
      sudo docker volume prune -f || true
      echo "After:"
      size_of /var/lib/docker
      echo "${GREEN}✔ Docker 清理完成${RESET}"
    else
      echo "${YELLOW}略過 Docker 清理${RESET}"
    fi
  fi
}

cleanup_podman() {
  if exists podman && sudo test -d /var/lib/containers; then
    headline "Podman 清理（未使用的 images/containers/volumes/build cache）"
    echo "Before:"
    size_of /var/lib/containers
    if confirm "執行 podman system prune -a -f？"; then
      sudo podman system prune -af || true
      echo "After:"
      size_of /var/lib/containers
      echo "${GREEN}✔ Podman 清理完成${RESET}"
    else
      echo "${YELLOW}略過 Podman 清理${RESET}"
    fi
  fi
}

cleanup_gitlab_backups() {
  local backups_dir="/opt/gitlab/backups"
  [[ -d "$backups_dir" ]] || { echo "${YELLOW}略過 GitLab 備份（找不到 $backups_dir）${RESET}"; return; }

  headline "GitLab 備份清理（$backups_dir）"
  echo "Before:"
  size_of "$backups_dir"
  read -r -p "刪除多少天前的備份？(預設 7) " days || true
  days="${days:-7}"
  if confirm "刪除 ${days} 天前的舊備份？（find … -mtime +$days -delete）"; then
    sudo find "$backups_dir" -type f -mtime +"$days" -print -delete || true
    echo "After:"
    size_of "$backups_dir"
    echo "${GREEN}✔ GitLab 舊備份清理完成${RESET}"
  else
    echo "${YELLOW}略過 GitLab 備份清理${RESET}"
  fi
}

cleanup_gitlab_artifacts() {
  local artifacts_dir="/opt/gitlab/shared/artifacts"
  [[ -d "$artifacts_dir" ]] || { echo "${YELLOW}略過 GitLab Artifacts（找不到 $artifacts_dir）${RESET}"; return; }

  headline "GitLab Artifacts 清理（$artifacts_dir）"
  echo "Before:"
  size_of "$artifacts_dir"
  read -r -p "刪除多少天前的 artifacts？(預設 7) " days || true
  days="${days:-7}"
  if confirm "刪除 ${days} 天前的 artifacts？（find … -mtime +$days -delete）"; then
    sudo find "$artifacts_dir" -type f -mtime +"$days" -print -delete || true
    echo "After:"
    size_of "$artifacts_dir"
    echo "${GREEN}✔ GitLab Artifacts 清理完成${RESET}"
  else
    echo "${YELLOW}略過 GitLab Artifacts 清理${RESET}"
  fi
}

cleanup_sonarqube_index() {
  # 適用 Docker 執行的 SonarQube，且資料卷掛載到 /opt/sonarqube/data
  local sq_data="/opt/sonarqube/data"
  [[ -d "$sq_data" ]] || { echo "${YELLOW}略過 SonarQube（找不到 $sq_data）${RESET}"; return; }

  headline "SonarQube 索引清理（將移除 ES 索引，重啟後自動重建）"
  echo "Before:"
  size_of "$sq_data"
  # 嘗試找容器
  local sq_cid=""
  if exists docker; then
    sq_cid=$(docker ps --format '{{.ID}} {{.Names}}' | awk '/sonarqube/{print $1}' | head -n1 || true)
  fi
  [[ -n "$sq_cid" ]] && echo "偵測到 SonarQube 容器：$sq_cid"

  if confirm "停止 SonarQube（若在 Docker），刪除 $sq_data/es* 來重建索引？"; then
    if [[ -n "$sq_cid" ]]; then
      docker stop "$sq_cid" || true
    fi
    # 移除 ES 索引（常見為 es7 / es6 目錄）
    sudo rm -rf "$sq_data"/es* || true
    if [[ -n "$sq_cid" ]]; then
      docker start "$sq_cid" || true
    fi
    echo "After:"
    size_of "$sq_data"
    echo "${GREEN}✔ SonarQube 索引清理完成${RESET}"
  else
    echo "${YELLOW}略過 SonarQube 索引清理${RESET}"
  fi
}

cleanup_snap() {
  if sudo test -d /var/lib/snapd; then
    headline "Snap 清理 / 移除"
    echo "Before:"
    size_of /var/lib/snapd
    if confirm "要移除整個 Snapd 與資料嗎？（停用 snapd 並移除 /var/lib/snapd 等）"; then
      sudo systemctl stop snapd || true
      if exists dnf; then sudo dnf -y remove snapd || true; fi
      safe_rm_rf /var/lib/snapd /snap /var/snap /home/*/snap
      echo "After:"
      size_of /var/lib/snapd
      echo "${GREEN}✔ Snap 已移除${RESET}"
    else
      # 若不移除，提供清理「已 disable 的舊修訂」
      if exists snap; then
        if confirm "僅清理 disabled 的舊 snap 修訂？"; then
          # 移除 disabled 版本
          sudo snap list --all | awk '/disabled/{print $1, $2}' | while read -r name rev; do
            sudo snap remove "$name" --revision="$rev" || true
          done
          echo "${GREEN}✔ 已清理 disabled 的 snap 修訂${RESET}"
        else
          echo "${YELLOW}略過 Snap 清理${RESET}"
        fi
      else
        echo "${YELLOW}系統無 snap 指令，略過${RESET}"
      fi
    fi
  fi
}

main() {
  echo "${GREEN}Space Cleaner 啟動${RESET}"
  section_sizes

  cleanup_tmp
  cleanup_docker
  cleanup_podman
  cleanup_gitlab_backups
  cleanup_gitlab_artifacts
  cleanup_sonarqube_index
  cleanup_snap

  headline "完成！目前佔用："
  section_sizes
  echo "${GREEN}✔ 全部步驟完成（你可以重新執行本工具進行定期清理）${RESET}"
}

main "$@"
