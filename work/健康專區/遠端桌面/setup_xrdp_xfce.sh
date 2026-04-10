#!/bin/bash
set -e

echo "===== 🖥️ 安裝必要套件 ====="
dnf install -y epel-release
dnf install -y xrdp podman xfce4-session xorgxrdp xorg-x11-fonts* xterm firewalld

echo "===== 🔧 啟動 xrdp 與防火牆 ====="
systemctl enable xrdp --now
systemctl enable firewalld --now
firewall-cmd --add-port=3389/tcp --permanent
firewall-cmd --reload

echo "===== ⚙️ 關閉 Wayland ====="
cat >/etc/gdm/custom.conf <<'EOF'
[daemon]
WaylandEnable=false
DefaultSession=gnome-xorg.desktop
EOF

echo "===== 🧱 建立容器映像 ====="
cat > /home/mike/Containerfile.xfce <<'EOF'
FROM rockylinux:9

COPY FG4H1FT922900257.crt /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust

ENV LANG=en_US.UTF-8
RUN dnf -y install epel-release && \
    dnf -y install \
      xfce4-session xfwm4 xfce4-panel xfdesktop thunar xfce4-settings xfconf \
      xfce4-terminal mousepad \
      dbus-x11 xorg-x11-xauth \
      dejavu-sans-fonts dejavu-serif-fonts dejavu-sans-mono-fonts \
      glibc-langpack-en && \
    dnf clean all

# 啟動腳本（由 entrypoint 呼叫）
RUN printf '%s\n' '#!/bin/sh' \
  'set -e' \
  'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$(id -u)}' \
  'mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"' \
  'exec dbus-launch --exit-with-session startxfce4' \
  > /usr/local/bin/start-xfce.sh && chmod +x /usr/local/bin/start-xfce.sh

CMD ["sh","-lc","exec /usr/local/bin/start-xfce.sh"]

EOF

podman build -t rocky-xfce -f /home/mike/Containerfile.xfce

echo "===== 🧩 修改 /etc/xrdp/startwm_xfce.sh ====="
cat > /etc/xrdp/startwm_xfce.sh <<'EOF'
#!/bin/bash
# xRDP -> Per-User Podman XFCE (rootless, single-bind, no profile)
# - HOME=/home，bind: ~/.xfcehome/$USER -> /home （用 :U,z）
# - 不讀 shell profile（--noprofile --norc）
# - 臨時 system bus in-container
# - 不使用 -t（避免 TTY 警告）

exec >/tmp/xrdp-startwm-xfce.log 2>&1
set -x

echo "=== $(date) user=$(whoami) ==="
echo "env DISPLAY=${DISPLAY}"

# 正規化 DISPLAY（:N.0 -> :N）
export DISPLAY="${DISPLAY:-:10}"
export DISPLAY="${DISPLAY%%.*}"

PODMAN_BIN="/usr/bin/podman"
XHOST_BIN="/usr/bin/xhost"
XSOCK="/tmp/.X11-unix"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# 每位使用者的持久化家目錄（XFCE 專用，不和 flashback 混放）
PERSIST_ROOT="$HOME/.xfcehome"; mkdir -p "$PERSIST_ROOT"
PERSIST_DIR="$PERSIST_ROOT/$USER"; mkdir -p "$PERSIST_DIR"

# 修擁有權 / 權限 + 建好 XDG 目錄骨架（host 側）
$PODMAN_BIN unshare bash -lc "
  chattr -R -i '$PERSIST_DIR' 2>/dev/null || true
  chown -R $(id -u):$(id -g) '$PERSIST_DIR'
  chmod 700 '$PERSIST_DIR'
  rm -f '$PERSIST_DIR/.profile' 2>/dev/null || true
  mkdir -p '$PERSIST_DIR'/.config '$PERSIST_DIR'/.cache '$PERSIST_DIR'/.local/share
  mkdir -p '$PERSIST_DIR'/Desktop '$PERSIST_DIR'/Documents '$PERSIST_DIR'/Downloads \
           '$PERSIST_DIR'/Pictures '$PERSIST_DIR'/Videos '$PERSIST_DIR'/Music \
           '$PERSIST_DIR'/Templates '$PERSIST_DIR'/Public
" || true

# SELinux（若啟用）
[ -x /sbin/restorecon ] && /sbin/restorecon -R "$PERSIST_DIR" 2>/dev/null || true

# 放行 X11
$XHOST_BIN +local: || true
$XHOST_BIN +SI:localuser:$(whoami) || true

CON_NAME="${USER}_desk_xfce"

# 執行容器（rootless）
exec $PODMAN_BIN run --rm -i \
  --pull=never \
  --userns=keep-id \
  --user "$(id -u):$(id -g)" \
  --name "$CON_NAME" \
  --entrypoint /usr/bin/env \
  -e DISPLAY="$DISPLAY" \
  -e XAUTHORITY="$XAUTHORITY" \
  -e LANG=en_US.UTF-8 \
  -e LC_ALL=en_US.UTF-8 \
  -e LANGUAGE=en_US:en \
  -e XDG_SESSION_TYPE=x11 \
  -e HOME="/home" \
  -e USER="$USER" \
  -e UID="$(id -u)" \
  -v "$XSOCK:$XSOCK:rw,z" \
  -v "$XAUTHORITY:$XAUTHORITY:ro,z" \
  -v "$PERSIST_DIR:/home:rw,z,U" \
  rocky-xfce:latest \
  bash --noprofile --norc -c '
    set -e
    # 臨時 system bus（給一些 daemon 用，不加也能跑，只是少數功能會告警）
    SYSBUS_DIR="/tmp/dbus-$(id -u)"
    mkdir -p "$SYSBUS_DIR"
    if command -v dbus-daemon >/dev/null 2>&1; then
      dbus-daemon --system \
        --address="unix:path=$SYSBUS_DIR/system_bus_socket" \
        --fork --nopidfile
      export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$SYSBUS_DIR/system_bus_socket"
    fi

    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$(id -u)}
    mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

    exec dbus-launch --exit-with-session startxfce4
  '

EOF

chmod +x /etc/xrdp/startwm_xfce.sh

echo "===== 🔄 重新啟動服務 ====="
systemctl restart xrdp
systemctl restart xrdp-sesman

