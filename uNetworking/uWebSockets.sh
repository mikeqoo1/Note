#!/bin/bash

# 設定輸出檔名
DOCKERFILE="Dockerfile.uWebSockets"

# 產生 Dockerfile
cat <<'EOF' > $DOCKERFILE
# 自動產生的 Dockerfile，用於編譯 uWebSockets + HTTP/3
FROM almalinux:9.5

COPY FG4H1FT922900257.crt /etc/pki/ca-trust/source/anchors/FG4H1FT922900257.crt
RUN update-ca-trust

RUN dnf install -y \
    gcc gcc-c++ cmake git make \
    zlib-devel libevent-devel \
 && dnf clean all

WORKDIR /opt

COPY libuv-devel-1.42.0-2.el9_4.x86_64.rpm /opt
RUN dnf -y install libuv-devel-1.42.0-2.el9_4.x86_64.rpm

RUN git clone --recursive https://github.com/uNetworking/uWebSockets.git

WORKDIR /opt/uWebSockets

# Build BoringSSL
RUN cd uSockets/boringssl && \
    cmake -DCMAKE_BUILD_TYPE=Release . && \
    make -j$(nproc) && \
    mkdir -p build/ssl build/crypto && \
    ln -s ../../libssl.a build/ssl/libssl.a && \
    ln -s ../../libcrypto.a build/crypto/libcrypto.a

ENV BORINGSSL=/opt/uWebSockets/uSockets/boringssl

# Build LSQUIC
RUN cd uSockets/lsquic && \
    git submodule update --init && \
    cmake -DBORINGSSL_DIR=${BORINGSSL} \
          -DZLIB_INCLUDE_DIR=/usr/include \
          -DZLIB_LIB=/usr/lib64/libz.so \
          -DCMAKE_C_FLAGS="-lstdc++" . && \
    make -j$(nproc) && \
    make install

# Build uSockets
RUN cd uSockets && \
    make -j$(nproc) \
        WITH_BORINGSSL=1 \
        BORINGSSL_INCLUDE_DIR=${BORINGSSL}/include \
        BORINGSSL_LIB_DIR=${BORINGSSL}/ssl

# Build uWebSockets with HTTP/3
RUN WITH_QUIC=1 WITH_BORINGSSL=1 make

CMD ["/bin/bash"]
EOF

# 提示使用者後續操作
echo "✅ Dockerfile 產生完成: $DOCKERFILE"
echo "👉 接下來可以這樣使用："
echo "   docker build -f $DOCKERFILE -t uwebsockets-http3 ."
echo "   docker run -it --rm --name test-uwebsockets uwebsockets-http3"
