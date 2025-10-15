#!/usr/bin/env bash
# setup_poddesk_flashback.sh
# Rocky Linux 9 + xRDP + Podman + GNOME Flashback (metacity)
# 以 root 執行： sudo bash setup_poddesk_flashback.sh
set -euo pipefail

# ---------- 基本參數 ----------
IMG_TAG="rocky-gnome-flashback:latest"
CF_DIR="/opt/poddesk"
CF_PATH="$CF_DIR/Containerfile.gflash"
STARTWM="/etc/xrdp/startwm.sh"
SESMAN="/etc/xrdp/sesman.ini"
XRDPINI="/etc/xrdp/xrdp.ini"

# 若要預先幫哪些使用者建 image（rootless），填在這裡（空白分隔）；預設只建 $SUDO_USER
USERS_TO_BUILD="${USERS_TO_BUILD:-${SUDO_USER:-}}"

echo "==> Installing packages (EPEL/CRB/xRDP/Podman/desktop deps)..."
dnf -y install 'dnf-command(config-manager)' || true
dnf config-manager --set-enabled crb || true
dnf -y install epel-release
dnf -y install xrdp xorgxrdp podman \
               dbus-x11 dbus-daemon \
               # 字型/多媒體依賴
               mesa-dri-drivers mesa-libGL mesa-libEGL \
               # 基本工具
               which nano less tar

echo "==> Ensure xrdp services enabled..."
systemctl enable --now xrdp xrdp-sesman

echo "==> Tuning xRDP to use Xorg + custom window manager..."
# xrdp.ini: 讓 [Xorg] 使用 libxorgxrdp.so + port=-1（預設即如此；保險起見確保）
sed -i 's/^\(\s*port\s*=\).*/\1 -1/' "$XRDPINI" || true

# sesman.ini: 使用我們的 startwm.sh
if grep -q '^EnableUserWindowManager' "$SESMAN"; then
  sed -i 's/^EnableUserWindowManager.*/EnableUserWindowManager=true/' "$SESMAN"
else
  printf '\n[Sessions]\nEnableUserWindowManager=true\n' >> "$SESMAN"
fi
if grep -q '^UserWindowManager' "$SESMAN"; then
  sed -i "s|^UserWindowManager.*|UserWindowManager=$STARTWM|" "$SESMAN"
else
  printf 'UserWindowManager=%s\n' "$STARTWM" >> "$SESMAN"
fi
if grep -q '^DefaultWindowManager' "$SESMAN"; then
  sed -i "s|^DefaultWindowManager.*|DefaultWindowManager=$STARTWM|" "$SESMAN"
else
  printf 'DefaultWindowManager=%s\n' "$STARTWM" >> "$SESMAN"
fi

echo "==> Writing GNOME Flashback Containerfile..."
mkdir -p "$CF_DIR"
cat > "$CF_PATH" <<'EOF'
FROM rockylinux:9

COPY FG4H1FT922900257.crt /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust

ENV LANG=en_US.UTF-8

RUN dnf -y install 'dnf-command(config-manager)' && dnf config-manager --set-enabled crb || true
RUN dnf -y install epel-release && \
    dnf -y install \
      gnome-flashback gnome-panel metacity \
      gnome-session gnome-session-xsession gnome-terminal \
      adwaita-gtk2-theme adwaita-icon-theme \
      dbus-x11 dbus-daemon xorg-x11-xauth xorg-x11-fonts* \
      dconf glib-networking gvfs xdg-user-dirs \
      mesa-dri-drivers mesa-libGL mesa-libEGL \
      glibc-langpack-en which nano less tar && \
    dnf clean all

# 可選 wrapper（實際上會被 run-time entrypoint 覆蓋）
RUN printf '%s\n' '#!/bin/sh' \
  'set -e' \
  'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$(id -u)}' \
  'mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"' \
  'xdg-user-dirs-update || true' \
  'exec dbus-launch --exit-with-session gnome-session --session=gnome-flashback-metacity' \
  > /usr/local/bin/start-flashback.sh && chmod +x /usr/local/bin/start-flashback.sh

CMD ["sh","-lc","exec /usr/local/bin/start-flashback.sh"]
EOF

echo "==> Installing startwm.sh (per-user Podman run)..."
cat > "$STARTWM" <<'EOF'
#!/bin/bash
# --- xRDP -> Per-User Podman GNOME Flashback (with logging) ---
exec >/tmp/xrdp-startwm.log 2>&1
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
EOF
chmod +x "$STARTWM"

echo "==> Restarting xRDP..."
systemctl restart xrdp xrdp-sesman

# ---------- 為使用者建立 rootless 映像 ----------
if [[ -n "${USERS_TO_BUILD}" ]]; then
  echo "==> Building image for users: ${USERS_TO_BUILD}"
  for u in ${USERS_TO_BUILD}; do
    if id "$u" &>/dev/null; then
      echo " -> Build for $u"
      runuser -l "$u" -c "mkdir -p $CF_DIR && cp -f $CF_PATH $CF_PATH.$u && podman build -t $IMG_TAG -f $CF_PATH.$u"
    fi
  done
else
  echo "==> NOTE: build the image once per user (rootless):"
  echo "    run as that user:  podman build -t $IMG_TAG -f $CF_PATH"
fi

echo "==> Done. Test by RDP login. Logs: /tmp/xrdp-startwm.log"
