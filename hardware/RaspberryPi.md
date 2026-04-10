# 樹莓派

### 增加硬碟空間

步驟&&指令

```
sudo df -h
sudo fdisk /dev/mmcblk0
輸入p (顯示所有的分割磁區, 紀錄最後一個分割的起始區間和結束區間)
輸入d (刪除磁區, 輸入最後的號碼就對了)
輸入2
輸入n (新建磁區, 給號碼, 給最後)
輸入2
警告出來, 不要怕, 按Y
輸入w
(第2段)
sudo reboot
sudo resize2fs /dev/mmcblk0p2 
sudo df -h
```


[警告說明](https://mlog.club/article/1850639)

### 影音串流Server
[uv4l-server實做](https://github.com/PietroAvolio/uv4l-webrtc-raspberry-pi)

[uv4l簡介](http://www.linux-projects.org/documentation/uv4l-server/)

[MJPG-Streamer實做](https://sites.google.com/site/rasberrypintust/shu-mei-pai-xiao-ji-qiao/webcam-server/mjpg-streamer)

[MJPG-Git](https://github.com/jacksonliam/mjpg-streamer)

[webrtc-To-ios](https://github.com/SmallpTsai/rpi-webrtc-streaming-to-ios/blob/master/README-tw.md)

### Linux上的Go程式編譯給RaspberryPI(ARM)的方法(交叉編譯)

簡易範例:

```makefile
# 樹莓派
pi:
	GOOS=linux GOARCH=arm GOARM=7 go build -v -o a.out test.go

# mac
mac:
	GOOS=darwin GOARCH=amd64 go build -o a.app test.go

# windows
windows:
	GOOS=windows GOARCH=amd64 go build -o a.exe test.go
```

### GPIO指令安裝

安裝:
```
sudo apt-get install wiringpi
pi@raspberrypi:~$  gpio readall
Oops - unable to determine board type... model: 17 (需要更新)
```

更新:
```
cd /tmp
wget https://project-downloads.drogon.net/wiringpi-latest.deb
sudo dpkg -i wiringpi-latest.deb

pi@raspberrypi:/tmp$  gpio readall
 +-----+-----+---------+------+---+---Pi 4B--+---+------+---------+-----+-----+
 | BCM | wPi |   Name  | Mode | V | Physical | V | Mode | Name    | wPi | BCM |
 +-----+-----+---------+------+---+----++----+---+------+---------+-----+-----+
 |     |     |    3.3v |      |   |  1 || 2  |   |      | 5v      |     |     |
 |   2 |   8 |   SDA.1 |  OUT | 0 |  3 || 4  |   |      | 5v      |     |     |
 |   3 |   9 |   SCL.1 |  OUT | 0 |  5 || 6  |   |      | 0v      |     |     |
 |   4 |   7 | GPIO. 7 |  OUT | 0 |  7 || 8  | 1 | IN   | TxD     | 15  | 14  |
 |     |     |      0v |      |   |  9 || 10 | 1 | IN   | RxD     | 16  | 15  |
 |  17 |   0 | GPIO. 0 |  OUT | 0 | 11 || 12 | 0 | IN   | GPIO. 1 | 1   | 18  |
 |  27 |   2 | GPIO. 2 |  OUT | 0 | 13 || 14 |   |      | 0v      |     |     |
 |  22 |   3 | GPIO. 3 |  OUT | 0 | 15 || 16 | 0 | IN   | GPIO. 4 | 4   | 23  |
 |     |     |    3.3v |      |   | 17 || 18 | 0 | IN   | GPIO. 5 | 5   | 24  |
 |  10 |  12 |    MOSI |  OUT | 0 | 19 || 20 |   |      | 0v      |     |     |
 |   9 |  13 |    MISO |  OUT | 0 | 21 || 22 | 0 | IN   | GPIO. 6 | 6   | 25  |
 |  11 |  14 |    SCLK |  OUT | 0 | 23 || 24 | 1 | IN   | CE0     | 10  | 8   |
 |     |     |      0v |      |   | 25 || 26 | 1 | IN   | CE1     | 11  | 7   |
 |   0 |  30 |   SDA.0 |   IN | 1 | 27 || 28 | 1 | IN   | SCL.0   | 31  | 1   |
 |   5 |  21 | GPIO.21 |  OUT | 0 | 29 || 30 |   |      | 0v      |     |     |
 |   6 |  22 | GPIO.22 |  OUT | 0 | 31 || 32 | 0 | IN   | GPIO.26 | 26  | 12  |
 |  13 |  23 | GPIO.23 |  OUT | 0 | 33 || 34 |   |      | 0v      |     |     |
 |  19 |  24 | GPIO.24 |  OUT | 0 | 35 || 36 | 0 | OUT  | GPIO.27 | 27  | 16  |
 |  26 |  25 | GPIO.25 |  OUT | 0 | 37 || 38 | 0 | OUT  | GPIO.28 | 28  | 20  |
 |     |     |      0v |      |   | 39 || 40 | 0 | OUT  | GPIO.29 | 29  | 21  |
 +-----+-----+---------+------+---+----++----+---+------+---------+-----+-----+
 | BCM | wPi |   Name  | Mode | V | Physical | V | Mode | Name    | wPi | BCM |
 +-----+-----+---------+------+---+---Pi 4B--+---+------+---------+-----+-----+
```