#!/bin/bash

set -e

# 🔧 建立 Dockerfile
cat <<'EOF' > Dockerfile
FROM almalinux:9.5

COPY FG4H1FT922900257.crt /etc/pki/ca-trust/source/anchors/FG4H1FT922900257.crt
RUN update-ca-trust

# 基礎套件
RUN dnf install -y epel-release && \
    dnf install -y gcc gcc-c++ make git cmake zlib-devel libevent-devel wget perl clang && \
    dnf install -y curl --allowerasing

# Node.js + npm (for later testing uws.js)
RUN curl -sL https://rpm.nodesource.com/setup_22.x | bash - && \
    dnf install -y nodejs

RUN export NODE_EXTRA_CA_CERTS=/etc/pki/ca-trust/source/anchors/FG4H1FT922900257.crt

COPY libuv-devel-1.42.0-2.el9_4.x86_64.rpm /opt

# 編譯目錄
WORKDIR /opt

RUN dnf -y install libuv-devel-1.42.0-2.el9_4.x86_64.rpm

# Clone uWebSockets.js (含子模組)
RUN git clone --recursive https://github.com/uNetworking/uWebSockets.js.git

# 編譯 uWebSockets C++ 支援 HTTP/3
WORKDIR /opt/uWebSockets.js/uWebSockets

# 編譯 BoringSSL
WORKDIR /opt/uWebSockets.js/uWebSockets/uSockets/boringssl
RUN cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=Release . && make -j$(nproc)
RUN mkdir -p build/ssl build/crypto && \
    ln -s ../../libssl.a build/ssl/libssl.a && \
    ln -s ../../libcrypto.a build/crypto/libcrypto.a
ENV BORINGSSL=/opt/uWebSockets.js/uWebSockets/uSockets/boringssl

# 編譯 LSQUIC
WORKDIR /opt/uWebSockets.js/uWebSockets/uSockets/lsquic
RUN git submodule update --init
RUN cmake \
  -DBORINGSSL_DIR=$BORINGSSL \
  -DZLIB_INCLUDE_DIR=/usr/include \
  -DZLIB_LIB=/usr/lib64/libz.so \
  -DCMAKE_C_FLAGS="-fPIC -lstdc++" \
  . && make -j$(nproc) && make install

# 編譯 uSockets
WORKDIR /opt/uWebSockets.js/uWebSockets/uSockets
RUN make -j$(nproc) \
  WITH_BORINGSSL=1 \
  BORINGSSL_INCLUDE_DIR=$BORINGSSL/include \
  BORINGSSL_LIB_DIR=$BORINGSSL/ssl

# 編譯 uWebSockets 本體 + HTTP3
WORKDIR /opt/uWebSockets.js/uWebSockets
RUN make WITH_QUIC=1 WITH_BORINGSSL=1

# 編譯 JS addon (binding)
WORKDIR /opt/uWebSockets.js

RUN mkdir -p uWebSockets/uSockets/boringssl/x64/ssl
RUN mkdir -p uWebSockets/uSockets/boringssl/x64/crypto
RUN mkdir -p uWebSockets/uSockets/lsquic/x64/src/liblsquic

RUN cp /opt/uWebSockets.js/uWebSockets/uSockets/boringssl/libssl.a /opt/uWebSockets.js/uWebSockets/uSockets/boringssl/x64/ssl/libssl.a
RUN cp /opt/uWebSockets.js/uWebSockets/uSockets/boringssl/libcrypto.a /opt/uWebSockets.js/uWebSockets/uSockets/boringssl/x64/crypto/libcrypto.a
RUN cp /opt/uWebSockets.js/uWebSockets/uSockets/lsquic/src/liblsquic/liblsquic.a  /opt/uWebSockets.js/uWebSockets/uSockets/lsquic/x64/src/liblsquic/

RUN make

# ⬇️ 輸出成果位置
VOLUME /output
RUN cp -r dist /output

EOF

# ✅ 建立 docker image
docker build -t uws-http3 .

# ✅ 進入容器中
docker run --rm -it uws-http3 bash

