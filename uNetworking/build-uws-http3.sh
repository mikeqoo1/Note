#!/bin/bash

set -e

# 🔧 建立 Dockerfile
cat <<'EOF' > Dockerfile
FROM almalinux:9

# ---------- 信任憑證 ----------
COPY FG4H1FT922900257.crt /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust

# ---------- 基礎工具 ----------
RUN dnf install -y epel-release && \
    dnf groupinstall -y "Development Tools" && \
    dnf install -y git cmake clang llvm perl wget curl-minimal python3 && \
    dnf clean all

# ---------- 官方 build.c 需要 clang-18 名稱 ----------
RUN ln -sf /usr/bin/clang   /usr/local/bin/clang-18
RUN ln -sf /usr/bin/clang++ /usr/local/bin/clang++-18

# ---------- 工作目錄 ----------
WORKDIR /opt

# ---------- 下載 uWebSockets.js + 子模組 ----------
RUN git clone --recursive https://github.com/uNetworking/uWebSockets.js.git

WORKDIR /opt/uWebSockets.js

# ---------- (關鍵) 使用官方編譯方式 ----------
# 官方 Makefile 本身就會：
# 1. 呼叫 build.c
# 2. 自動編 BoringSSL
# 3. 自動編 lsquic
# 4. 自動編 uSockets
# 5. 最後產生 dist/*.node
ENV WITH_QUIC=1
ENV WITH_BORINGSSL=1

RUN make -j"$(nproc)"

# ---------- 導出編譯產物 ----------
VOLUME /output
RUN cp -r dist /output

EOF

# ✅ 建立 docker image
docker build -t uws-http3 .

# ✅ 進入容器中
docker run --rm -it uws-http3 bash

