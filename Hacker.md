
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
