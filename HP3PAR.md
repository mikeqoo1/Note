# HP 3PAR

## 簡介

反正就是一張卡片會生成虛擬的硬碟空間 資料會寫到別的大容量主機

## 設定

1. 先用指令 lsscsi 確認連接

```sh
lsscsi
[0:1:124:0]  enclosu BROADCOM VirtualSES       03    -        
[0:3:111:0]  disk    BROADCOM MR9560-16i       5.16  /dev/sda 
[13:0:0:0]   cd/dvd  HL-DT-ST DVDRAM GUE1N     AS00  /dev/sr0 
[25:0:0:0]   disk    3PARdata VV               4521  /dev/sdb 
[25:0:0:254] enclosu 3PARdata SES              4521  -        
[25:0:1:0]   disk    3PARdata VV               4521  /dev/sdc 
[25:0:1:254] enclosu 3PARdata SES              4521  -        
[25:0:2:254] enclosu 3PARdata SES              4521  -        
[25:0:3:254] enclosu 3PARdata SES              4521  -        
[26:0:0:0]   disk    3PARdata VV               4521  /dev/sdd 
[26:0:0:254] enclosu 3PARdata SES              4521  -        
[26:0:1:254] enclosu 3PARdata SES              4521  -        
[26:0:2:0]   disk    3PARdata VV               4521  /dev/sde 
[26:0:2:254] enclosu 3PARdata SES              4521  -        
[26:0:3:254] enclosu 3PARdata SES              4521  -        
```

2. 安裝工具

```sh
sudo dnf install multipath-tools sg3_utils
```

3. 建立設定檔

```txt
sudo vi /etc/multipath.conf

內容如下:

defaults {
    user_friendly_names yes
    find_multipaths no
}

blacklist {
    devnode "^sd[a]"
}

devices {
    device {
        vendor "3PARdata"
        product "VV"
        path_grouping_policy group_by_prio
        path_checker tur
        no_path_retry queue
        hardware_handler "0"
        prio alua
        failback immediate
    }
}
```

4. 載入設定檔

```txt
sudo modprobe dm-multipath
sudo systemctl restart multipathd
```

5. 掃描新磁碟 確保機器可以偵測倒 3PAR

```sh
sudo rescan-scsi-bus.sh
```

6. 檢查並顯示 LUN

```sh
sudo multipath -v2
sudo multipath -ll
執行完應該會有這些
mpatha (360002ac0000000000000000f00028638) dm-3 3PARdata,VV
size=1.0T features='1 queue_if_no_path' hwhandler='1 alua' wp=rw
`-+- policy='service-time 0' prio=50 status=active
  |- 25:0:0:0 sdb 8:16 active ready running
  |- 25:0:1:0 sdc 8:32 active ready running
  |- 26:0:0:0 sdd 8:48 active ready running
  `- 26:0:2:0 sde 8:64 active ready running
```

7. 查看磁區

```sh
lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sda           8:0    0  1.7T  0 disk  
├─sda1        8:1    0  600M  0 part  /boot/efi
├─sda2        8:2    0    1G  0 part  /boot
└─sda3        8:3    0  1.7T  0 part  
  ├─rl-root 253:0    0   70G  0 lvm   /
  ├─rl-swap 253:1    0    4G  0 lvm   [SWAP]
  └─rl-home 253:2    0  1.7T  0 lvm   /home
sdb           8:16   0    1T  0 disk  
└─mpatha    253:3    0    1T  0 mpath 
sdc           8:32   0    1T  0 disk  
└─mpatha    253:3    0    1T  0 mpath 
sdd           8:48   0    1T  0 disk  
└─mpatha    253:3    0    1T  0 mpath 
sde           8:64   0    1T  0 disk  
└─mpatha    253:3    0    1T  0 mpath 
sr0          11:0    1 1024M  0 rom   

從 lsblk 的輸出來看，/dev/sdb、/dev/sdc、/dev/sdd 和 /dev/sde 被正確地配置為多路徑設備，並合併為單一的多路徑設備 mpatha。接下來我們需要對 mpatha 創建文件系統，然後掛載該文件系統。
```

8. 對 mpatha 創建文件系統

```sh
sudo mkfs.ext4 /dev/mapper/mpatha
```

9. 掛載多路徑設備

```sh
sudo mkdir /mnt/3par_data
```

10. 掛載文件系統

```sh
sudo mount /dev/mapper/mpatha /mnt/3par_data
```

11. 確認掛載成功

```sh
df -h /mnt/3par_data
```

