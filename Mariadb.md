# Mariadb的相關手冊

## 安裝篇

```
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
```

## Galera篇

#### 步驟1.
2台host和hostname需要先設定完成,設定方法如下:

```
sudo hostname 主機名稱

接下來編輯/etc/hostname文件並更新主機名稱
sudo vi /etc/hostname

最後，編輯/etc/hosts文件並更新主機名稱
sudo vi /etc/hosts
```
#### 步驟2.
2邊的系統都要建立一個同步用的帳號, 大部分都使用root就好

#### 步驟3.
都先關閉2邊的DB,接下來去設定DB config, 設定好後, 啟動一邊, 記得使用
galera_new_cluster來啟動, 成功開啟後, 另一邊就用sudo systemctl start 的方式啟動就好
