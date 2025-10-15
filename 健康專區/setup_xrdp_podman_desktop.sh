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
# 需要中文就加：ENV LANG=zh_TW.UTF-8
# 並安裝： glibc-langpack-zh

RUN dnf -y install epel-release && \
    # ① 安裝完整 XFCE 核心元件
    dnf -y install \
      xfce4-session xfwm4 xfce4-panel xfdesktop thunar xfce4-settings \
      xfce4-terminal \
    # ② X/DBus 相關
      dbus-x11 xorg-x11-xauth xorg-x11-fonts* \
    && dnf clean all

# 建立容器內使用者（可依需要調整）
RUN useradd -m mike && echo "mike:1234" | chpasswd
USER mike
WORKDIR /home/mike

# 以 dbus-launch 帶起 session（比單純 startxfce4 穩）
CMD ["sh","-lc","exec dbus-launch --exit-with-session startxfce4"]

EOF

podman build -t rocky-xfce -f /home/mike/Containerfile.xfce

echo "===== 🧩 修改 /etc/xrdp/startwm.sh ====="
cat > /etc/xrdp/startwm.sh <<'EOF'
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

EOF

chmod +x /etc/xrdp/startwm.sh

echo "===== 🔄 重新啟動服務 ====="
systemctl restart xrdp
systemctl restart xrdp-sesman

echo "===== ✅ 完成設定 ====="
echo
echo "➡ 現在可以從 Windows / macOS 使用遠端桌面 (RDP)"
echo "   連線到這台主機的 IP（port 3389）"
echo "   登入帳號：$(whoami)"
echo
echo "登入後畫面會自動載入容器的 XFCE 桌面"
echo "容器使用者：mike / 密碼：1234"
