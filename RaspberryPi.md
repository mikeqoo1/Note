# 樹莓派


### 增加硬碟空間

步驟&&指令

```
sudo df -h
sudo fdisk /dev/mmcblk0
輸入p (顯示所有的分割磁區, 紀錄最後一個分割的起始區間和結束區間)
輸入d (刪除磁區, 輸入最後的號碼就對了)
輸入2
輸入p (新建磁區, 給號碼, 給最後)
輸入2
警告出來, 不要怕, 按Y
輸入w
(第2段)
sudo reboot
sudo resize2fs /dev/mmcblk0p2 
sudo df -h
```


[警告說明](https://mlog.club/article/1850639)
