#!/bin/bash
# --- xRDP -> Per-User Podman GNOME Flashback (with logging) ---
exec >/tmp/xrdp-startwm-poddesk.log 2>&1
set -x

echo "=== $(date) user=$(whoami) ==="
echo "env DISPLAY=${DISPLAY}"

# 正規化 DISPLAY（:13.0 -> :13）
export DISPLAY="${DISPLAY:-:10}"
export DISPLAY="${DISPLAY%%.*}"

PODMAN_BIN="/usr/bin/podman"
XHOST_BIN="/usr/bin/xhost"
XSOCK="/tmp/.X11-unix"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# 各使用者自己的持久化家目錄：~/.poddesk/$USER
PERSIST_ROOT="$HOME/.poddesk"; mkdir -p "$PERSIST_ROOT"
PERSIST_DIR="$PERSIST_ROOT/$USER"; mkdir -p "$PERSIST_DIR"

# 放寬當前 X session 訪問權限（避免 UID 映射問題）
$XHOST_BIN +local: || true
$XHOST_BIN +SI:localuser:$(whoami) || true

CON_NAME="${USER}_desk"

# 執行容器（rootless；英文介面）
exec $PODMAN_BIN run --rm -it \
  --pull=never \
  --userns=keep-id \
  --name "$CON_NAME" \
  --entrypoint /bin/sh \
  -e DISPLAY="$DISPLAY" \
  -e XAUTHORITY="$XAUTHORITY" \
  -e LANG=en_US.UTF-8 \
  -e LC_ALL=en_US.UTF-8 \
  -e LANGUAGE=en_US:en \
  -e XDG_SESSION_TYPE=x11 \
  -e XDG_CURRENT_DESKTOP="GNOME-Flashback:GNOME" \
  -e DESKTOP_SESSION=gnome-flashback-metacity \
  -e GDMSESSION=gnome-flashback-metacity \
  -e HOME="/home/$USER" \
  -e USER="$USER" \
  -e UID="$(id -u)" \
  -v "$XSOCK:$XSOCK:rw,z" \
  -v "$XAUTHORITY:$XAUTHORITY:ro,z" \
  -v "$PERSIST_DIR:/home/$USER:rw,z" \
  rocky-gnome-flashback:latest \
  -lc '
    set -e
    # 1) runtime 目錄
    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$(id -u)}
    mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

    # 2) 在 /tmp 啟 system bus（rootless 可寫）
    SYSBUS_DIR="/tmp/dbus-$(id -u)"
    mkdir -p "$SYSBUS_DIR"
    if command -v dbus-daemon >/dev/null 2>&1; then
      dbus-daemon --system \
        --address="unix:path=$SYSBUS_DIR/system_bus_socket" \
        --fork --nopidfile
      export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$SYSBUS_DIR/system_bus_socket"
    fi

    # 3) 明確走 X11；初始化 XDG 目錄
    export GDK_BACKEND=x11
    xdg-user-dirs-update || true

    # 4) 起 GNOME Flashback（metacity）
    exec dbus-launch --exit-with-session gnome-session --session=gnome-flashback-metacity
  '