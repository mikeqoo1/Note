# Readis 簡易文件

## Install in ContOS

指令如下:
```
sudo dnf install redis
sudo systemctl start redis
sudo systemctl enable redis
sudo firewall-cmd --permanent --zone=public --add-port=6379/tcp
sudo firewall-cmd --reload
sudo redis-server -v
#效能測試 http://redis.io/topics/benchmarks
redis-benchmark -q -n 100000
sudo redis-cli
```

## 設定檔
/etc/redis.conf：普通單一的redis server設定檔, 預設port是6379

/etc/redis-sentinel.conf：管理多個redis, 實現高可用性功能, 預設port是26379
```
#bind 設定
#0.0.0.0 全部都可連
#127.0.0.1 只能本機連
bind 127.0.0.1

#設定快取資料儲存到硬碟的頻率
#900秒內有1次更新
save 900 1
#300秒內有10次更新
save 300 10
#60秒內有10000次更新
save 60 10000

#AUTH 密碼設定
#http://redis.readthedocs.org/en/latest/connection/auth.html
#若允許不信任的IP連線，可以設定密碼(官方建議設複雜一點,因為redis速度很快,可以在短時間被惡意測試很多密碼)
requirepass 密碼
```

## Redis 指令
```
#本機連線
redis-cli
#指定 port、IP 連線
redis-cli -p 6379 -h 127.0.0.1
#有設密碼時，須先用 auth 指令認證
127.0.0.1:6379> AUTH 密碼
#測試
127.0.0.1:6379> ping
#取得 server 全部設定值
127.0.0.1:6379> CONFIG GET *
#設定String類型快取資料
127.0.0.1:6379> set k1 test
OK
#取得String類型快取資料
127.0.0.1:6379> get k1
"test"
#取得所有key
127.0.0.1:6379> keys *
#取得PHP開頭的key
127.0.0.1:6379> keys PHP*
1) "PHPREDIS_SESSION:n47g4vh1qt2pltplkd3lhifes2"
2) "PHPREDIS_SESSION:qp2fj1dpff0rgt6lakno4nrlh1"
#查看伺服器資訊
127.0.0.1:6379> info
#切換到1號DB (編號從0開始，預設為0)
127.0.0.1:6379> select 1
OK
127.0.0.1:6379[1]>
#刪除 key 為 k1 的資料
1127.0.0.1:6379> del k1
(integer) 1
#清空目前DB所有資料
127.0.0.1:6379> flushdb
OK
#清空全部DB的資料 
127.0.0.1:6379> flushall
OK
#查詢資料剩多久過期
#-1表示沒設定過期時間
#-2表示key不存在
127.0.0.1:6379> TTL k1
(integer) -1
127.0.0.1:6379> TTL ktest
(integer) -2
#設定資料多久後過期(毫秒)，例如設定 k1 在 8 秒後過期
#成功返回1，失敗或key不存在返回0
127.0.0.1:6379> pexpire k1 8000
(integer) 1
#列出目前 client 端的連線
127.0.0.1:6379> CLIENT LIST
```

### 參考

https://blog.csdn.net/anyway8090/article/details/105023398

https://hoxis.github.io/redis-conf.html

https://blog.csdn.net/ljheee/article/details/76284082

https://www.twblogs.net/a/5df07a28bd9eee310da0d38d