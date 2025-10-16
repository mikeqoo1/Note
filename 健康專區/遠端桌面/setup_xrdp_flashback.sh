#!/usr/bin/env bash
# setup_xrdp_flashback.sh
# Rocky Linux 9 + xRDP + Podman + GNOME Flashback (metacity)
# 以 root 執行： sudo bash setup_xrdp_flashback.sh
set -euo pipefail

# ---------- 基本參數 ----------
IMG_TAG="rocky-gnome-flashback:latest"
CF_DIR="/opt/flashback"
CF_PATH="$CF_DIR/Containerfile.gflash"
STARTWM="/etc/xrdp/startwm_flashback.sh"
SESMAN="/etc/xrdp/sesman.ini"
XRDPINI="/etc/xrdp/xrdp.ini"

# 若要預先幫哪些使用者建 image（rootless），填在這裡（空白分隔）；預設只建 $SUDO_USER
USERS_TO_BUILD="${USERS_TO_BUILD:-${SUDO_USER:-}}"

echo "==> Installing packages (EPEL/CRB/xRDP/Podman/desktop deps)..."
dnf -y install 'dnf-command(config-manager)' || true
dnf config-manager --set-enabled crb || true
dnf -y install epel-release

echo "==> Ensure xrdp services enabled..."
systemctl enable --now xrdp xrdp-sesman

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

# Wrapper (實際上會被 run-time entrypoint 覆蓋)
RUN printf '%s\n' '#!/bin/sh' \
  'set -e' \
  'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$(id -u)}' \
  'mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"' \
  'xdg-user-dirs-update || true' \
  'exec dbus-launch --exit-with-session gnome-session --session=gnome-flashback-metacity' \
  > /usr/local/bin/start-flashback.sh && chmod +x /usr/local/bin/start-flashback.sh

CMD ["sh","-lc","exec /usr/local/bin/start-flashback.sh"]
EOF

# 讓使用者能讀 Containerfile
chmod 0644 "$CF_PATH"
chmod 0755 "$CF_DIR"

echo "==> Installing startwm_flashback.sh (per-user Podman run)..."
cat > "$STARTWM" <<'EOF'
#!/bin/bash
# xRDP -> Per-User Podman GNOME Flashback (fixed v4)
# - HOME=/home（單一 bind：$PERSIST_DIR -> /home，使用 :U,z 做 ID 與 SELinux 調整）
# - 不讀任何 shell profile（bash --noprofile --norc）
# - 容器內啟臨時 system bus
# - 不再對 /home 本身 mkdir，僅建立子目錄

exec >/tmp/xrdp-startwm-flashback.log 2>&1
set -x

echo "=== $(date) user=$(whoami) ==="
echo "env DISPLAY=${DISPLAY}"

# 正規化 DISPLAY（:10.0 -> :10）
export DISPLAY="${DISPLAY:-:10}"
export DISPLAY="${DISPLAY%%.*}"

PODMAN_BIN="/usr/bin/podman"
XHOST_BIN="/usr/bin/xhost"
XSOCK="/tmp/.X11-unix"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# 每位使用者的持久化家目錄（在 host）
PERSIST_ROOT="$HOME/.flashback"; mkdir -p "$PERSIST_ROOT"
PERSIST_DIR="$PERSIST_ROOT/$USER"; mkdir -p "$PERSIST_DIR"

# 修擁有權/權限 + 建好 XDG 目錄（host 側）
$PODMAN_BIN unshare bash -lc "
  chattr -R -i '$PERSIST_DIR' 2>/dev/null || true
  chown -R $(id -u):$(id -g) '$PERSIST_DIR'
  chmod 700 '$PERSIST_DIR'
  # 乾淨化可能壞掉的 profile
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

CON_NAME="${USER}_desk"

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
  -e XDG_CURRENT_DESKTOP="GNOME-Flashback:GNOME" \
  -e DESKTOP_SESSION=gnome-flashback-metacity \
  -e GDMSESSION=gnome-flashback-metacity \
  -e HOME="/home" \
  -e USER="$USER" \
  -e UID="$(id -u)" \
  -v "$XSOCK:$XSOCK:rw,z" \
  -v "$XAUTHORITY:$XAUTHORITY:ro,z" \
  -v "$PERSIST_DIR:/home:rw,z,U" \
  rocky-gnome-flashback:latest \
  bash --noprofile --norc -c '
    set -e

    # 臨時 system bus（給 gsd/colord/upower 等用）
    SYSBUS_DIR="/tmp/dbus-$(id -u)"
    mkdir -p "$SYSBUS_DIR"
    if command -v dbus-daemon >/dev/null 2>&1; then
      dbus-daemon --system \
        --address="unix:path=$SYSBUS_DIR/system_bus_socket" \
        --fork --nopidfile
      export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$SYSBUS_DIR/system_bus_socket"
    fi

    # 最小化 XDG 需求（注意：這裡不再對 $HOME 自己 mkdir）
    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$(id -u)}
    mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
    export GDK_BACKEND=x11
    xdg-user-dirs-update || true

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
      # 用 root 建好的 Containerfile，讓使用者自行 build
      runuser -l "$u" -c "podman build -t '$IMG_TAG' -f '$CF_PATH' '$CF_DIR'"
    fi
  done
else
  echo "==> NOTE: build the image once per user (rootless):"
  echo "    run as that user:  podman build -t $IMG_TAG -f $CF_PATH $CF_DIR"
fi

echo "==> Done. Test by RDP login. Logs: /tmp/xrdp-startwm.log"
