#!/bin/bash
# Dispatcher：依 DESKTOP_MODE 決定桌面環境
exec >/tmp/xrdp-startwm.log 2>&1
set -x

echo "=== $(date) ==="
echo "USER=$(whoami)"
echo "DISPLAY=${DISPLAY:-<unset>}"
echo "DESKTOP_MODE=${DESKTOP_MODE:-<unset>}"

# 根據 DESKTOP_MODE 決定要啟動哪個環境
case "${DESKTOP_MODE}" in
  gnome|poddesk|gnome-flashback|flashback)
    MODE="gnome"
    echo "→ 啟動 GNOME Flashback 容器"
    exec /etc/xrdp/startwm_flashback.sh
    ;;
  xfce)
    MODE="xfce"
    echo "→ 啟動 XFCE 容器"
    exec /etc/xrdp/startwm_xfce.sh
    ;;
  *)
    MODE="gnome"
    echo "→ 未指定 DESKTOP_MODE，預設啟動 GNOME"
    exec /etc/xrdp/startwm_flashback.sh
    ;;
esac