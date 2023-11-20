# Linux 基本指令

## 開始

### 新增使用者

sudo useradd 帳號名稱

### 新增群組

sudo groupadd 群組名稱

### 設定密碼

sudo passwd 帳號名稱

### 指定群組

指定主要群組: sudo useradd -g 主要群組名稱 帳號名稱

加入其他群組: sudo useradd -g 主要群組名稱 -G 次要群組1,次要群組2 帳號名稱

### 修改主要群組

usermod -g 主要群組 帳號名稱

### 增加次要群組

usermod -a -G 次要群組 帳號名稱

### 同時更改擁有者與群組

檔案:sudo chown user:group File

資料夾:sudo chown -R user:group Folder

### 查詢資料夾大小

du -shc /home/Projects/*

### Linux Disk I/O 效能測試 - sysbench

安裝:yum install sysbench

準備測試假資料:sysbench --test=fileio --num-threads=20 --file-total-size=1G --file-test-mode=rndrw prepare

讀寫測試:sysbench --test=fileio --num-threads=20 --file-total-size=1G --file-test-mode=rndrw run

刪除假資料:sysbench --test=fileio --num-threads=20 --file-total-size=1G --file-test-mode=rndrw cleanup

資料庫效能測試
mysql.socket路徑 (預設:/var/lib/mysql/mysql.sock)
先新建foo=>create database foo

查看哪些lua腳本

```bash
rpm -ql sysbench | grep 'bin\|lua'  
/usr/bin/sysbench
/usr/share/sysbench/bulk_insert.lua
/usr/share/sysbench/oltp_common.lua
/usr/share/sysbench/oltp_delete.lua
/usr/share/sysbench/oltp_insert.lua
/usr/share/sysbench/oltp_point_select.lua
/usr/share/sysbench/oltp_read_only.lua
/usr/share/sysbench/oltp_read_write.lua
/usr/share/sysbench/oltp_update_index.lua
/usr/share/sysbench/oltp_update_non_index.lua
/usr/share/sysbench/oltp_write_only.lua
/usr/share/sysbench/select_random_points.lua
/usr/share/sysbench/select_random_ranges.lua
/usr/share/sysbench/tests/include/inspect.lua
/usr/share/sysbench/tests/include/oltp_legacy/bulk_insert.lua
/usr/share/sysbench/tests/include/oltp_legacy/common.lua
/usr/share/sysbench/tests/include/oltp_legacy/delete.lua
/usr/share/sysbench/tests/include/oltp_legacy/insert.lua
/usr/share/sysbench/tests/include/oltp_legacy/oltp.lua
/usr/share/sysbench/tests/include/oltp_legacy/oltp_simple.lua
/usr/share/sysbench/tests/include/oltp_legacy/parallel_prepare.lua
/usr/share/sysbench/tests/include/oltp_legacy/select.lua
/usr/share/sysbench/tests/include/oltp_legacy/select_random_points.lua
/usr/share/sysbench/tests/include/oltp_legacy/select_random_ranges.lua
/usr/share/sysbench/tests/include/oltp_legacy/update_index.lua
/usr/share/sysbench/tests/include/oltp_legacy/update_non_index.lua
```

先建立測試Table:sysbench --db-driver=mysql --mysql-user=帳號 --mysql-password=密碼 --mysql-socket=mysql.socket路徑 --mysql-db=資料庫 --range_size=100 --table_size=10000 --tables=2 --threads=1 --events=0 --time=60 --rand-type=uniform /usr/share/sysbench/oltp_read_only.lua prepare

開始測試:sysbench --db-driver=mysql --mysql-user=帳號 --mysql-password=密碼 --mysql-socket=mysql.socket路徑 --mysql-db=資料庫 --range_size=100 --table_size=10000 --tables=2 --threads=1 --events=0 --time=60 --rand-type=uniform /usr/share/sysbench/oltp_read_only.lua run

刪除假資料:sysbench --db-driver=mysql --mysql-user=帳號 --mysql-password=密碼 --mysql-socket=mysql.socket路徑 --mysql-db=資料庫 --range_size=100 --table_size=10000 --tables=2 --threads=1 --events=0 --time=60 --rand-type=uniform /usr/share/sysbench/oltp_read_only.lua cleanup

CPU 壓力測試
sysbench cpu --cpu-max-prime=20000 --threads=64 --time=3600 run

I/O測試 I/O的性能因Block Storage大小而異, Block Storage越小, 吞吐量越小, IOPS越高 這邊都採用16K

1個Thread 1個檔案數量

sysbench fileio --threads=1 --time=10 --file-num=1 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw prepare

sysbench fileio --threads=1 --time=10 --file-num=1 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw run

sysbench fileio --threads=1 --time=10 --file-num=1 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw cleanup

1個Thread 多個檔案數量

sysbench fileio --threads=1 --time=10 --file-num=4 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw prepare

sysbench fileio --threads=1 --time=10 --file-num=4 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw run

sysbench fileio --threads=1 --time=10 --file-num=4 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw cleanup
多個Thread 1個檔案數量
sysbench fileio --threads=64 --time=10 --file-num=1 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw prepare

sysbench fileio --threads=64 --time=10 --file-num=1 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw run

sysbench fileio --threads=64 --time=10 --file-num=1 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw cleanup
多個Thread 多個檔案
sysbench fileio --threads=64 --time=10 --file-num=4 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw prepare
sysbench fileio --threads=64 --time=10 --file-num=4 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw run
sysbench fileio --threads=64 --time=10 --file-num=4 --file-block-size=16K --file-total-size=8G --file-test-mode=rndrw cleanup

Linux File I/O 分3種模式
O_DIRECT: I/O operations performed against files opened with O_DIRECT bypass the kernel's page cache, writing directly to the storage.
O_SYNC: File data and all file metadata are written synchronously to disk.
O_DSYNC: Only file data and metadata needed to access the file data are written synchronously to disk. Metadata that is not required for retrieving the data of the file may not be written immediately.

上面的解释非常不清楚，我找到了這篇名为“UNIX高级环境编程（14）文件IO - O_DIRECT和O_SYNC详解 < 海棠花溪 >”的文章。看了之后，才终于懂了這两個flag的区别。

O_DIRECT：用于让IO从使用者态直接跨过“stdio缓冲区的高速缓存”和“内核缓冲区的高速缓存”，直接写到存储上。

O_SYNC：用于控制“内核缓冲区的高速缓存”直接写到存储上，即强制刷新内核缓冲区到输出文件的存储。


I/O缓冲的过程是這样的：
使用者數據 –> stdio缓冲区 –> 内核缓冲区高速缓存 –> 硬碟

可见，上面的两個flag的区别是O_DIRECT让IO从使用者數據中直接到硬碟（跨过了两個缓冲区），而O_SYNC让IO从内核缓冲区直接到硬碟（仅跨过了内核缓冲区）。


### CentOS8.x設定

DNS設定

```bash
sudo vi /etc/resolv.conf
內容如下:
# Generated by NetworkManager
search concords.com.tw
nameserver 8.8.8.8
nameserver 8.8.8.8
```

憑證更換

```bash
I. 匯出 Windows的受信任的根憑證授權單位，採用「Base-64編碼 X.509 (.CER)
II. 將憑證複製到 CentOS 的 /etc/pki/ca-trust/source/anchors
III. 執行 sudo chmod 755 [憑證的名字].cer 
III. 執行 sudo update-ca-trust
IV. 開啟 Firefox，偏好設定 -> 隱私權與安全性 -> 憑證 -> 檢視憑證 -> 匯入剛剛載入的憑證(網站及郵件)
```

### Ubuntu 基本開發工具

node.js 使用nvm來安裝

golang 使用apt-get install golang

byobu htop mycli 都是一樣的

MaraiDB 10.4 install - <https://computingforgeeks.com/install-mariadb-10-on-ubuntu-18-04-and-centos-7/>

Ubuntu的防火牆指令是 sudo ufw allow 80/tcp

### Ubuntu下gcc/g++多版本共存和版本切換

```bash
sudo apt-get install gcc-7 (安裝別的版本)
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 50  (設定版本權重, 100是自動)
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 50  (設定版本權重)
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 100 (設定版本權重)
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 50
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 50
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 100
sudo update-alternatives --config gcc(選用版本)
sudo update-alternatives --config g++(選用版本)
```

### Ubuntu手動安裝deb

```bash
sudo dpkg -i 軟體套件名.deb
```

### system service

### centos8 的自動補全功能

```bash
dnf install bash-completion -y
```

### 建立SFTP

- <https://www.opencli.com/linux/rhel-centos-7-install-sftp>

建立帳號, 設定目錄, 調整權限, 修改SSH的設定檔

```bash
sudo adduser NEW_USER
```

```bash
sudo passwd NEW_USER
```

```bash
sudo mkdir -p SFTP_DIRECTORY (ex:/var/sftp/abc)
```

```bash
sudo chown root:root SFTP_DIRECTORY_ROOT (ex:/var/sftp)
```

```bash
sudo chmod 755 SFTP_DIRECTORY_ROOT
```

```bash
sudo chown NEW_USER:NEW_USER SFTP_DIRECTORY
```

```bash
sudo vi /etc/ssh/sshd_config
```

ADD THIS --->

```bash
Match User NEW_USER
ForceCommand internal-sftp
PasswordAuthentication yes
ChrootDirectory SFTP_DIRECTORY_ROOT
PermitTunnel no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
```

```bash
重新啟動服務
sudo systemctl restart sshd
```


時區問題: Server開啟sftp的chroot功能, Client登入後, ls -l顯示的時間不是Server的時間, 而是差了一個時區, 需要+8小時才是對的
解法: 把系统的時區文件複製到sftp user下

```bash
ll /usr/share/zoneinfo/Asia/Taipei
cd /home/r6emst/
sudo mkdir etc
sudo cp -r /usr/share/zoneinfo/Asia/Taipei etc/localtime
```

### 小指令集合

```bash
查看目錄大小
du -chd 1 | sort -h

顯示秒數
ls -l --time-style='+%H:%M:%S'
```

### objdump 反編譯

### nc (netcat)

當一個簡單的TCP Server
nc -l port

當一個簡單的TCP Client
nc ip port

https://blog.gtwang.org/linux/linux-utility-netcat-examples/
https://myapollo.com.tw/zh-tw/linux-command-nc/
https://kknews.cc/zh-tw/code/ky8r8z8.html

### stress-ng (升級版的sysbench)

                IP Address
EMTS-01         IP:192.168.199.133
EMTS-02         IP:192.168.199.134
EMTS-QA-01      IP:192.168.199.227
EMTS-QA-02      IP:192.168.199.250

https://ephrain.net/linux-%E5%9C%A8-centos-%E4%B8%8A%E4%BD%BF%E7%94%A8-stress-%E6%A8%A1%E6%93%AC%E7%B3%BB%E7%B5%B1%E8%B3%87%E6%BA%90%E5%90%83%E7%B7%8A%E7%9A%84%E7%8B%80%E6%B3%81-cpu%E8%A8%98%E6%86%B6%E9%AB%94/

install

sudo dnf -y install stress-ng
sudo dnf -y install sysstat (用於Linux的性能監視工具的集合)

針對CPU的壓力測試, 在所有的 CPU 上執行各種 stressors, 持續 1 小時
stress-ng --cpu 0 --cpu-method all -t 1h

針對記憶體測試
stress-ng --vm 8 --vm-bytes 80% -t 1h

https://officeguide.cc/linux-stress-ng-cpu-memory-hard-drive-full-load-tutorial-examples/

https://www.51cto.com/article/707986.html

https://blog.csdn.net/weixin_43991475/article/details/124980475?spm=1001.2101.3001.6650.2&utm_medium=distribute.pc_relevant.none-task-blog-2%7Edefault%7ECTRLIST%7ERate-2-124980475-blog-121461501.pc_relevant_default&depth_1-utm_source=distribute.pc_relevant.none-task-blog-2%7Edefault%7ECTRLIST%7ERate-2-124980475-blog-121461501.pc_relevant_default&utm_relevant_index=4




lspci -Dm | grep -i raid
0000:c1:00.0 "RAID bus controller" "Broadcom / LSI" "MegaRAID 12GSAS/PCIe Secure SAS39xx" "Broadcom / LSI" "MegaRAID 9560-16i"




https://www.alibabacloud.com/blog/testing-io-performance-with-sysbench_594709
https://juejin.cn/post/6844903744904118279
https://help.aliyun.com/document_detail/25382.html
https://docs.aws.amazon.com/zh_tw/AWSEC2/latest/UserGuide/ebs-io-characteristics.html
https://www.twblogs.net/a/5d407e00bd9eee51fbf99df1
http://linux.51yip.com/search/sysbench
https://www.cnblogs.com/awpatp/p/8777796.html
https://blog.csdn.net/hilaryfrank/article/details/112200386
http://laoar.github.io/blog/2017/04/28/directio/
https://zhuanlan.zhihu.com/p/374627314
https://elinux.org/images/5/5c/Lyon-stress-ng-presentation-oct-2019.pdf

### Lastlog文件一直變大的原因

```txt
Lastlog文件是紀錄所有使用者最後登入的相關資訊，該文件的算法是：紀錄使用者登入信息大小 = UID * 256byte

如64位系统上的nfsnobody使用者，其UID是4294967294 或者 2^32 - 2，這也是系统上最後一個的UID。
所以通過上面的算法就能說明該文件顯示1.2TB大小：4294967294 * 256 = 1099511627264 bytes。

從上面的算法也可以知道，256是每一UID在lostlog文件中所佔用的空間大小。

所以這種文件就是所谓的sparse(稀疏)文件，就是在文件中留有很多剩餘空間，預先備用將來插入數據使用。這些剩餘空間被ASCII碼的NULL佔據，並且這些空間相當大，這個文件就被稱为稀疏文件，但是並不分配相應的硬碟塊。也就是没有真正佔用文件系统空間。所以你就不用擔心了這個文件佔用了1.2TB的空間了。你可以用[du -h /var/log/lastlog]來查他看到真正佔用硬碟的空間。
```

### NetworkManager 使用

[介紹](https://how64bit.com/posts/linux/2022/linux-net-configure/)

```bash
查看網卡狀態
nmcli dev show 網卡名稱
```

```txt
參數說明
con-name : 設定檔名稱
ipv4.method : 設定靜態IP( manual )或是動態DHCP( auto )取得
ipv4.addresses : ipv4 + 子網路遮罩 ( prefix length 表示)
ipv4.gateway : 預設閘道
ipv4.dns : dns
connection.autoconnect : 開機自動選此設定
type : 網路類型
ifname : 綁定網路卡
```

```bash
新增網卡設定
nmcli con add 網卡名稱 參數
con-name example ipv4.method manual ipv4.addresses 172.25.250.12/24 ipv4.gateway 172.25.250.1 ipv4.dns 8.8.8.8 connection.autoconnect yes type ethernet  ifname enp1s0 

啟用網路設定
nmcli con up example 
```

```bash
編輯網卡設定
nmcli con modify 網卡名稱 參數
```

## 開啟 gdb core file

```bash
ulimit -c unlimited (要永久生效 把這段加在/etc/profile)
sudo mkdir /corefile
sudo chmod 777 corefile/
sysctl -w kernel.core_pattern=/corefile/core.%e.%p.%s.%E

DEBUG 步驟
gdb 執行檔路徑 corefile路徑
(gdb) bt
(gdb) info registers
(gdb) list
```
