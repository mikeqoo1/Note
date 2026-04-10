#!/bin/bash
# --- xRDP -> Podman 容器桌面 啟動器（含偵錯）---
exec >/tmp/xrdp-startwm.log 2>&1
set -x

echo "=== $(date) ==="
echo "whoami=$(whoami)"
echo "env DISPLAY=${DISPLAY}"

# 1) DISPLAY 正規化（:13.0 -> :13）
export DISPLAY="${DISPLAY:-:10}"
export DISPLAY="${DISPLAY%%.*}"

# 2) 準備路徑變數
PODMAN_BIN="/usr/bin/podman"
XHOST_BIN="/usr/bin/xhost"
SUDO_BIN="/usr/bin/sudo"
XSOCK="/tmp/.X11-unix"

# Xauthority（xRDP Xorg 會在家目錄建立）
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# 3) 放寬本機 X 存取（避免 uid 映射問題）
$XHOST_BIN +local: || true
$XHOST_BIN +SI:localuser:$(whoami) || true

# 4) 影像 / 容器名
IMG_NAME="localhost/rocky-xfce:latest"
CON_NAME="${USER}_desk"

$PODMAN_BIN images

# 5) 若容器已在跑 → 直接 exec
if $PODMAN_BIN ps --format '{{.Names}}' | grep -qx "$CON_NAME"; then
  exec $PODMAN_BIN exec -it "$CON_NAME" bash -lc 'startxfce4'
fi

# 6) rootless 跑；失敗再 sudo
run_cmd="$PODMAN_BIN run --rm -it \
  --name $CON_NAME \
  -e DISPLAY=$DISPLAY \
  -e XAUTHORITY=$XAUTHORITY \
  -v $XSOCK:$XSOCK:rw,z \
  -v $XAUTHORITY:$XAUTHORITY:ro,z \
  $IMG_NAME"

echo "Run container: $run_cmd"
eval "$run_cmd"
RC=$?
echo "rootless run exit code: $RC"

if [ $RC -ne 0 ]; then
  echo "Fallback: sudo podman run"
  eval "$SUDO_BIN -n $run_cmd"
fi

echo "=== end $(date) ==="