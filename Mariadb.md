# Mariadb的相關手冊

## 安裝篇

```txt
1.sudo vi /etc/yum.repos.d/MariaDB.repo
檔案內容如下 
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.4/centos8-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1

2.sudo dnf install boost-program-options
3.sudo dnf install MariaDB-server MariaDB-client --disablerepo=AppStream 
4.sudo systemctl enable --now mariadb
5.sudo mysql_secure_installation

更換資料庫的目錄
1.sudo systemctl stop mariadb
2.sudo mkdir /database/mariadb
3.sudo cp -Rp /var/lib/mysql/* /database/mariadb
4.sudo chown -R mysql:mysql /database/mariadb
5. sudo vi /etc/my.cnf
內容如下
    [mysqld]
    datadir = /database/mariadb
```

## 權限篇

```sql
CREATE USER 'dbuser'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@'%' IDENTIFIED BY PASSWORD 'password';(不含管理權限)
GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@'%' IDENTIFIED BY PASSWORD 'password' WITH GRANT OPTION;(最高權限, 同root)
SHOW GRANTS FOR 'user'@'%';(查看帳號權限)

(1372, 'Password hash should be a 41-digit hexadecimal number')如何處理
select password('[你的密碼明碼]');
create user '帳號'@'%' identified by password '你的加密密碼';
select password('Aa1234');
重新設定密碼：
SET PASSWORD FOR 'dbuser'@'%' = '你的加密密碼';
SET PASSWORD FOR 'crcft'@'%' = '*E798321A750FDD829997240D5DC2F2FFC4D06D6D';


GRANT USAGE ON *.* TO `intrauser`@`%` IDENTIFIED BY PASSWORD '*E798321A750FDD829997240D5DC2F2FFC4D06D6D';
GRANT SELECT ON `CRCFT`.* TO `intrauser`@`%`; 
GRANT SELECT ON `EMTS`.* TO `intrauser`@`%`;


select password('110084');
GRANT USAGE ON *.* TO `110084`@`%` IDENTIFIED BY PASSWORD '*EC5CCEC1DE4C476E935BE052BD7097232AEA8AD0';
GRANT SELECT ON *.* TO `110084`@`%`;
GRANT ALL ON *.* TO `mis_107096`@`%`
ftpinstant
遠端登入無法的問題 在設定檔加入 skip-grant-tables
```

## Galera篇

### 步驟1

2台host和hostname需要先設定完成,設定方法如下:

```txt
sudo hostname 主機名稱

接下來編輯/etc/hostname文件並更新主機名稱
sudo vi /etc/hostname

最後, 編輯/etc/hosts文件並更新主機名稱
sudo vi /etc/hosts
```

### 步驟2

2邊的系統都要建立一個同步用的帳號, 大部分都使用root就好

### 步驟3

都先關閉2邊的DB,接下來去設定DB config, 設定好後, 啟動一邊, 記得使用
galera_new_cluster來啟動, 成功開啟後, 另一邊就用sudo systemctl start 的方式啟動就好

#### 驗證同步

```sql
show STATUS LIKE 'wsrep%';
SHOW STATUS LIKE "wsrep_cluster_size";
show STATUS LIKE "wsrep_cluster_status";
show STATUS LIKE "wsrep_local_state_comment";
```

踩坑紀錄
galera mysql cluster 故障node再次接入集群遇到的問題

- <http://blog.itpub.net/133735/viewspace-2140548/>

```txt
結論 避開這個問題的方法 就是 機器的配置 wsrep-cluster-address 的選項裡, 本機的ip不要放在第一位
```

重新啟動同步, 失敗的處理方式

- <https://www.cnblogs.com/nulige/articles/8470001.html>

常用的除錯指令:

show full processlist 可以看到所有連接的情况, 但是大多連接的 state 其實是 Sleep 的, 空閒的狀態, 没有太多問題

過濾sleep的狀態
select id, db, user, host, command, time, state, info from information_schema.processlist where command != 'Sleep' order by time desc

id - process ID (可以用：kill id)
command - 當下執行的命令, 比如最常見的:Sleep, Query, Connect...
time - 花費的時間(秒)
state - 執行狀態, 比如:Sending data, Sorting for group, Creating tmp table, Locked...
info - 執行的SQL語法

explain 分析一下 SQL 語法

Command 的值：

```txt
Binlog Dump: 主node正在將二進位log, 同步到從node
Change User: 正在執行一個change-user的操作
Close Stmt: 正在關閉一個Prepared Statement对象
Connect: 一個node連上了主node
Connect Out: 一個從node正在連主node
Create DB: 正在執行一個create-database的操作
Daemon: DB内部process, 而不是來自User的連線
Delayed Insert: 該process是一個延遲插入的處理程序
Drop DB: 正在執行一個drop-database的操作
Execute: 正在執行一個Prepared Statement
Fetch: 正在從Prepared Statement中獲取執行结果
Field List: 正在獲取表的列信息
Init DB: 該process正在選取一個默認的DB
Kill : 正在執行kill語法, 殺死指定process
Long Data: 正在從Prepared Statement中查看long data
Ping: 正在處理server-ping的請求
Prepare: process正在準備一個Prepared Statement
ProcessList: process正在產生process相關訊息
Register Slave： 正在註冊從node
Reset Stmt: 正在重置prepared statement
Set Option: 正在設定或重置User的statement-execution選項
Statistics: process正在產生server-status信息
Time: Unused
```

## Galera異常失去同步復原篇

情況1 當備份的DB關閉的時候, 直接起動, 不需要更改任何設定

情況2 當整個DB集合關閉的時候, 選一個當頭, 修改grastate.dat的內容, 把seqno改1, 執行galera_new_cluster
其他的節點systemctl start mariadb

```bash
vi grastate.dat

# GALERA saved state
version: 2.1
uuid:    675d9d38-61de-11ea-9d6e-c75c611ddc7e
seqno:   -1
safe_to_bootstrap: 0
```

情況3 當主要頭的DB關閉的時候, 請去其他節點, 修改grastate.dat的內容, safe_to_bootstrap: 0 改 1, 強行當頭同步

## Table Metadata Lock

- 1. 有大query卡住, 阻塞DDL, 阻塞所有同表的後續操作

```txt
show processlist
kill掉DDL的session
```

- 2. 沒有提交的commit, 阻塞DDL, 阻塞所有同表的後續操作

```txt
select * from information_schema.innodb_trx\G
找到未提交的sid, 然後kill掉
```

- 3. 都沒有大query, 和沒提交的commit

```txt
(該語法有執行完畢但是狀態是Sleep, 就是未提交, 就會看不到對應的trx_query)
SELECT * FROM information_schema.innodb_trx;

通過performance_schema.events_statements_current來檢查對應的sql, 包含已經執行完, 但没有提交的

SELECT b.processlist_id, c.db, a.sql_text, c.command, c.time, c.state
FROM performance_schema.events_statements_current a JOIN performance_schema.threads b USING(thread_id)
JOIN information_schema.processlist c ON b.processlist_id = c.id
WHERE a.sql_text NOT LIKE '%performance%';

kill掉Sleep的
```

## mysql效能分析show profile/show profiles

show profile 和 show profiles 語句可以展示當前會話 (退出session後, profiling重置為0) 中執行語句的資源使用情況

Profiling 功能由MySQL會話變數: profiling控制, 預設是OFF 關閉狀態 select @@profiling; OR show variables like '%profi%';

開啟Profiling功能：

```sql
SET PROFILING = 1;
```

```sql
SHOW PROFILES; [顯示最近傳送到伺服器上執行的語句的資源使用情況 顯示的記錄數由變數(profiling_history_size)控制, 預設15筆]

SHOW PROFILE; [顯示最近一條語句執行的詳細資源佔用資訊, 預設顯示Status和Duration]

[show profile 還可根據 show profiles 列表中的 Query_ID ,選擇顯示某條記錄的效能分析資訊]

SHOW PROFILE FOR QUERY id;


Syntax:
SHOW PROFILE [type] FOR QUERY n
type={ALL|BLOCK IO|CONTEXT SWITCHES|CPU|IPC|MEMORY|PAGE FAULTS|SOURCE|SWAPS}
```

已開啟連線數目

```sql
SHOW STATUS LIKE '%connected';
```


（1）匯出整個資料庫(包括資料庫中的資料）

    mysqldump -h ip -u username -p dbname > dbname.sql

（2）匯出資料庫結構（不含資料）

    mysqldump -h ip -u username -p -d dbname > dbname.sql

（3）匯出資料庫中的某張資料表（包含資料）

    mysqldump -h ip -u username -p dbname tablename > tablename.sql

（4）匯出資料庫中的某張資料表的表結構（不含資料）

    mysqldump -h ip -u username -p -d dbname tablename > tablename.sql

匯入
mysql -h ip -u username -p dbname < tablename.sql

## 審計log (MariaDB Audit Plugin)


MariaDB Audit Plugin[https://mariadb.com/kb/en/mariadb-audit-plugin/]

Locating the Plugin

```sql
SHOW GLOBAL VARIABLES LIKE 'plugin_dir';
+---------------+--------------------------+
| Variable_name | Value                    |
+---------------+--------------------------+
| plugin_dir    | /usr/lib64/mysql/plugin/ |
+---------------+--------------------------+
```

Installing the Plugin

```sql
INSTALL SONAME 'server_audit';
```

豐富的審計内容：包括User連線，關閉，DML操作，過程，觸發事件，事件等。
靈活的審計策略：可以自定義審計事件，例如過濾掉select查詢，或者排除審計某个User等。
靈活方便：免費使用，可以在線打開和停用審計功能。

```txt
MariaDB [(none)]> show variables like '%server_audit%';
+-------------------------------+-----------------------+
| Variable_name                 | Value                 |
+-------------------------------+-----------------------+
| server_audit_events           |                       |
| server_audit_excl_users       |                       |
| server_audit_file_path        | server_audit.log      |
| server_audit_file_rotate_now  | OFF                   |
| server_audit_file_rotate_size | 1000000               |
| server_audit_file_rotations   | 9                     |
| server_audit_incl_users       |                       |
| server_audit_logging          | OFF                   |
| server_audit_mode             | 0                     |
| server_audit_output_type      | file                  |
| server_audit_query_log_limit  | 1024                  |
| server_audit_syslog_facility  | LOG_USER              |
| server_audit_syslog_ident     | mysql-server_auditing |
| server_audit_syslog_info      |                       |
| server_audit_syslog_priority  | LOG_INFO              |
+-------------------------------+-----------------------+
server_audit_events：指定紀錄事件的類型，可以用逗號分隔的多個值(connect,query,table)，默認為空代表審計所有事件
server_audit_excl_users：User白名單，該列表中的User行為將不紀錄
server_audit_file_path：存log的文件，默認在var/lib/mysql的 server_audit.log 文件中
server_audit_file_rotate_now：强制log文件輪轉
server_audit_file_rotate_size：限制log文件的大小
server_audit_file_rotations：指定log文件的數量，如果為0 log將從不輪轉
server_audit_incl_users：指定哪些User的活動將紀錄，connect將不受此變量影響，該變量比 server_audit_excl_users 優先級高
server_audit_loc_info: 内部参數，用不到
server_audit_logging：啟動或關閉審計，默認OFF，啟動ON
server_audit_mode：識別版本，用於開發和測試
server_audit_output_type：指定log輸出類型，可為SYSLOG或FILE
server_audit_query_log_limit: 紀錄中查詢的結果的長度限制。默認為1024
server_audit_syslog_facility：默認為LOG_USER，指定facility
server_audit_syslog_ident：設置ident，作為每個syslog紀錄的一部分
server_audit_syslog_info：指定的info的結果將添加到syslog紀錄
server_audit_syslog_priority：定義紀錄log優先級

線上設定
set global server_audit_logging=on;

config設定
server_audit_logging=on
```




