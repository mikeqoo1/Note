# 安裝 uWebSockets

## 開始之前：安裝必要套件

```bash
sudo dnf install -y cmake gcc-c++ git zlib-devel libevent-devel make
```

## Clone uWebSockets 與子模組

```bash
git clone https://github.com/uNetworking/uWebSockets.git
cd uWebSockets
git submodule update --init --recursive
```

## 編譯 BoringSSL

```bash
cd uSockets/boringssl
cmake -DCMAKE_BUILD_TYPE=Release .
make -j$(nproc)
export BORINGSSL=$PWD

## 這樣 uWebSockets 的 Makefile 會自動抓對了。
mkdir -p build/ssl build/crypto
ln -s ../../libssl.a build/ssl/libssl.a
ln -s ../../libcrypto.a build/crypto/libcrypto.a
```

## 編譯 LSQUIC（靜態庫）

```bash
cd ../lsquic

git submodule update --init  # 確保 LSQUIC 的子模組完整

cmake \
  -DBORINGSSL_DIR=$BORINGSSL \
  -DZLIB_INCLUDE_DIR=/usr/include \
  -DZLIB_LIB=/usr/lib64/libz.so \
  -DCMAKE_C_FLAGS="-lstdc++" \
  .

make -j$(nproc)

make install
```

## 編譯 uSockets（靜態庫）

```bash
cd ..

make -j$(nproc) \
  WITH_BORINGSSL=1 \
  BORINGSSL_INCLUDE_DIR=$BORINGSSL/include \
  BORINGSSL_LIB_DIR=$BORINGSSL/ssl

```

## 編譯 uWebSockets + HTTP/3 範例

```bash
WITH_QUIC=1 WITH_BORINGSSL=1 make
```

# 安裝 uWebSockets.js


