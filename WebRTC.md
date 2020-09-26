# Ubuntu 下編譯 WebRTC

## 前置作業

一般的開發工具gcc, g++等...

特殊套件版本 git 版本 >=2.2.1, Python version = 2.7


## Google套件安裝

作法是先建立一個資料夾, 把google的專案clone下來, 新增環境變數, 接著同步

```
步驟1: mkdir ~/Workspace
步驟2: git clone https://Workspace.googlesource.com/Workspace/tools/depot_tools.git (獲取depot_tools)
步驟3: vi ~/.bashrc 在裡面新增 [export PATH=~/Workspace/depot_tools:"$PATH"]
步驟4: source ~/.bashrc (生效)
步驟5: cd depot_tools/
步驟6: gclient sync
```

## 下載並且編譯WebRTC

```
步驟1: mkdir ~/Workspace/webrtc
步驟2: fetch --nohooks webrtc
步驟3: gclient sync

(選配)指定追蹤新的分支:
git config branch.autosetupmerge always
git config branch.autosetuprebase always
```

## 編譯WebRTC

WebRTC 目前使用 GN 来生成建構脚本，Ninja 進行建構

- 生成 Ninja 文件

Ninja 文件由 GN 生成, 選擇一個放置的目錄中，如 out/Debug 或者 out/Release, 這裡官方建議選擇 out/Default 這樣可以放 debug 和 release

```
步驟1: cd ~/Workspace/webrtc/src
步驟2: gn gen out/Default
步驟3: ninja -C out/Default
```

## 編譯RPi-WebRTC-Streamer

有2個部份有要處理rpi_rootfs和Rpi-WebRTC-Streamer

- rpi_rootfs

步驟如下:
```
cd ~/Workspace
git clone https://github.com/kclyu/rpi_rootfs
cd rpi_rootfs
mkdir tools
cd tools
(執行腳本)
sudo ../scripts/gdrive_download.sh 1q7Zk-7NhVROrBBWVgm56PbndZauSZL27 gcc-linaro-8.3.0-2019.03-x86_64_arm-linux-gnueabihf.tar.xz
xz -dc gcc-linaro-8.3.0-2019.03-x86_64_arm-linux-gnueabihf.tar.xz  | tar xvf -
ln -sf gcc-linaro-8.3.0-2019.03-x86_64_arm-linux-gnueabihf  arm-linux-gnueabihf
cd /opt
sudo ln -sf ~/Workspace/rpi_rootfs
暫時生效: export PATH=/opt/rpi_rootfs/tools/arm-linux-gnueabihf/bin:$PATH
永久生效 {
    vi ~/.bashrc
    在本來的export PATH後面加入/opt/rpi_rootfs/tools/arm-linux-gnueabihf/bin
    最後會變成這樣export PATH=~/Workspace/depot_tools:/opt/rpi_rootfs/tools/arm-linux-gnueabihf/bin:"$PATH"
}
cd ~/Workspace/rpi_rootfs
./build_rootfs.sh download
unzip yyyy-mm-dd-raspios-buster-armhf.zip
./build_rootfs.sh create yyyy-mm-dd-raspios-buster-armhf.img
```


- Rpi-WebRTC-Streamer

步驟如下:
```
cd ~/Workspace
git clone https://github.com/kclyu/rpi-webrtc-streamer

前置處理
需要把Rpi-WebRTC-Streamer的sn檔丟去webrtc中編譯
做法如下
cd ~/Workspace/webrtc/src/out/
mkdir arm_build
cd ~/Workspace/rpi-webrtc-stremer/misc/
cp webrtc_arm_build_args.gn ~/Workspace/webrtc/src/out/arm_build/args.gn
cd ~/Workspace/webrtc/src
gn gen out/arm_build
ninja -C out/arm_build
cd ~/Workspace/rpi-webrtc-streamer/src
make
```

重新編譯:
```
cd ~/Workspace/webrtc/src
gn clean out/arm_build
gn gen out/arm_build
ninja -C out/arm_build
cd ~/Workspace/rpi-webrtc-streamer/src
make clean
make
```

## 測試方法

把build好的執行檔webrtc-streamer, 丟到樹莓派上面跑就知道了