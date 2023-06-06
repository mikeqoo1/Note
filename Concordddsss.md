# 康x技能包

## 憑證問題

```bash
先把IE的憑證匯出來, ??????.cer

上網 處理方法 For Ubuntu
sudo cp ??????.cer /etc/ssl/certs

npm 處理方法
npm config set cafile "/path/??????.cer"

snap 處理方法
openssl x509 -inform der -in ??????.cer -out xxxx.pem
sudo snap set system store-certs.cert1="$(cat /path/xxxx.pem)"

For Rocky/CentOS
sudo cp ??????.cer /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

## 系統裝機手冊2.0

```linux
sudo dnf update
sudo dnf install epel-release
sudo dnf install htop

遠端桌面選配安裝

先裝GUI桌面
dnf groupinstall "Server with GUI" -y
systemctl set-default graphical
reboot

再裝xrdp服務
dnf install --nogpgcheck https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
dnf install xrdp tigervnc-server -y
systemctl start xrdp
systemctl enable xrdp
systemctl status xrdp
firewall-cmd --zone=trusted --add-port=3389/tcp --permanent
firewall-cmd --zone=public --add-port=3389/tcp --permanent
firewall-cmd --reload
firewall-cmd --list-all


git 設定
git config --global user.name "199250"
git config --global user.email 192168199250@concords.com.tw
git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(blue)<%an>%Creset' --abbrev-commit --all"

npm config set cafile "~/certificate.crt"

```

## 安裝 MariaDB 10.6

sudo vi /etc/yum.repos.d/mariadb.repo

```ini
[mariadb] 
name = MariaDB 
baseurl = http://yum.mariadb.org/10.6/rhel8-amd64 
module_hotfixes=1 
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB 
gpgcheck=1
```

```ini
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.9/rhel9-amd64
module_hotfixes=1
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1 
```

安裝步驟跟設定

```ini
sudo dnf install mariadb-server mariadb
sudo systemctl start mariadb
sudo systemctl status mariadb
sudo mariadb-secure-installation
```

### 同步設定

sudo vim /etc/hosts

```ini
192.168.0.1 node1
192.168.0.2 node2
192.168.0.3 node3
```

sudo vi /etc/my.cnf

設定檔複製到節點2 節點3 ip 名稱換一換

```ini
#
# This group is read both by the client and the server
# use it for options that affect everything
#
[client-server]

#
# include *.cnf from the config directory
#
!includedir /etc/my.cnf.d
[mysqld]
character-set-server    = 'utf8mb4'
collation-server        = 'utf8mb4_unicode_ci'
#datadir                  = /database/mariadb
skip_character_set_client_handshake = 1   #跳過mysql登入時候的字符集參數設定 使用Server端的設定
binlog_format            = ROW
#binlog_format            = MIXED
# 基於語句紀錄： STATEMENT，只紀錄語句。該模式存在弊端，比如執行"UPDATE students SET birth = now();"無法保存具体的時間戳記，若按照該語句進行還原準確性肯定出現問題。
# 基於行紀錄：ROW，只紀錄數據，即直接將數據存下来，但檔案大小較大。適合資料相對重要的場景。資料恢复時準確性的最高，但需要犧牲更多的硬碟空間。
# 混合模式： MIXED 系统自行判定該用哪個方式存
#MariaDB 5.5.x默認STATEMENT, 而MariaDB 10.2.x默認MIXED
default-storage-engine   = innodb
innodb_autoinc_lock_mode = 2
bind-address             = 0.0.0.0

wait_timeout            = 86400   #24hr
interactive_timeout     = 86400
max_allowed_packet      = 67108864 #64M
net_buffer_length       = 65536

general_log              = 1
general_log_file         = /var/lib/mysql/mariadb.log

slow_query_log           = 1 #0=關閉 1=打開
slow_query_log_file      = /var/lib/mysql/query_slow.log
long_query_time          = 0.1 #執行超過0.1秒

log-error                = /var/lib/mysql/error.log
log_bin_trust_function_creators = 1
log_bin                  = /var/lib/mysql/mariadb_bin.log
max_binlog_size          = 1073741824 #log大小
sync_binlog              = 0 #設定是否啟動binlog即时同步硬碟功能，默認0，由操作系统負責同步log到硬碟
expire_logs_days         = 3 #保留3天

max_connections             = 8192

innodb_use_native_aio       = ON #Linux default=ON
innodb_read_io_threads      = 16
innodb_write_io_threads     = 16
innodb_thread_concurrency   = 64 #default=0 表示不限制

wsrep_provider_options="gcache.size=1024M"
wsrep_provider_options="repl.max_ws_size=2147483647"

# Galera Provider Configuration
[galera]
wsrep_on                 = ON
wsrep_cluster_name       = "MariaDB Galera Cluster"
wsrep_provider           = /usr/lib64/galera-4/libgalera_smm.so
wsrep_cluster_address    = "gcomm://192.168.0.1,192.168.0.2,192.168.0.3"

# Galera Synchronization Configuration
wsrep_sst_method         = rsync


# Galera Node Configuration
wsrep_node_address       = "192.168.0.1"
wsrep_node_name          = "node1"


# audit Log
server_audit_logging          = ON
server_audit_events           = connect,query_ddl,query_dml,query_dcl,table
plugin-load-add               = server_audit.so
server_audit_output_type      = file
server_audit_file_rotate_now  = ON
server_audit_file_rotate_size = 5G
server_audit_file_rotations   = 10
```

防火牆開啟

```ini
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --permanent --zone=public --add-port=4567/tcp
sudo firewall-cmd --permanent --zone=public --add-port=4568/tcp
sudo firewall-cmd --permanent --zone=public --add-port=4444/tcp
sudo firewall-cmd --permanent --zone=public --add-port=4567/udp
sudo firewall-cmd --reload
```

關閉SELINUX

vi /etc/selinux/config

```ini
SELINUX=disabled
```

第一台的啟動 sudo galera_new_cluster 其他 sudo systemctl start mariadb

## Haproxy2.4.8

```ini
wget https://www.lua.org/ftp/lua-5.3.5.tar.gz
tar xzf lua-5.3.5.tar.gz
cd lua-5.3.5
sudo dnf install readline-devel
sudo make linux install

wget http://www.haproxy.org/download/2.4/src/haproxy-2.4.8.tar.gz
tar xzf haproxy-2.4.8.tar.gz
cd haproxy-2.4.8
sudo yum install pcre-devel
sudo dnf install systemd-devel
make -j $(nproc) TARGET=linux-glibc USE_OPENSSL=1 USE_LUA=1 USE_PCRE=1 USE_SYSTEMD=1
sudo make install
```

haproxy檢查與重啟概念

```bash
haproxy -v  #Version
haproxy -f /etc/haproxy/haproxy.cfg -c  #檢查
service haproxy restart

sudo groupadd haproxy #建立帳號和群組
sudo useradd -g haproxy haproxy
sudo mkdir /var/lib/haproxy
```

## GitLab

```bash
# 1.產生private key
openssl genrsa -out gitlab.key 2048
# 2.某某vm或服務(例如:iis、apache)產生certificate signing request (CSR)
openssl req -new -key gitlab.key -out gitlab.csr
# 3.作簽章(用private key對CSR作簽章)
openssl x509 -req -days 3650 -in gitlab.csr -signkey gitlab.key -out gitlab.crt
# 4. 產生stronger DHE parameters 
openssl dhparam -out dhparam.pem 2048
sudo mkdir -p /srv/docker/gitlab/gitlab/certs # 這是host的目錄喔，會對到gitlab的/home/git/data
sudo mkdir -p /srv/docker/gitlab/postgresql
sudo mkdir -p /srv/docker/gitlab/redis
sudo cp gitlab.key /srv/docker/gitlab/gitlab/certs/
sudo cp gitlab.crt /srv/docker/gitlab/gitlab/certs/
sudo cp dhparam.pem /srv/docker/gitlab/gitlab/certs/
sudo chmod 400 /srv/docker/gitlab/gitlab/certs/gitlab.key # read
sudo docker-compose up # 啟動
```

## podman 的啟動

```bash

有待更新 確認

sudo podman pod create -n concords --network podman -p 10022:22 -p 10080:80 -p 10443:443

sudo podman run --cap-add=AUDIT_WRITE --pod concords --name gitlab-postgresql -d \
    --env 'DB_NAME=gitlabhq_production' \
    --env 'DB_USER=gitlab' --env 'DB_PASS=password' \
    --env 'DB_EXTENSION=pg_trgm' \
    --volume /srv/docker/gitlab/postgresql:/var/lib/postgresql \
    sameersbn/postgresql:12-20200524

sudo podman run --pod concords --name gitlab-redis -d \
    --volume /srv/docker/gitlab/redis:/data \
    redis:6.2

sudo podman run --cap-add=AUDIT_WRITE --pod concords --add-host=192.168.199.236 --name gitlab -d \
    --env 'GITLAB_HOST=192.168.199.236' \
    --env 'GITLAB_SSH_PORT=10022' --env 'GITLAB_PORT=10443' \
    --env 'GITLAB_HTTPS=true' --env 'SSL_SELF_SIGNED=true' \
    --env 'GITLAB_SECRETS_DB_KEY_BASE=long-and-random-alpha-numeric-string' \
    --env 'GITLAB_SECRETS_SECRET_KEY_BASE=long-and-random-alpha-numeric-string' \
    --env 'GITLAB_SECRETS_OTP_KEY_BASE=long-and-random-alpha-numeric-string' \
    --volume /srv/docker/gitlab/gitlab:/home/git/data sameersbn/gitlab:14.8.2
```

### 母親節禮物

先啟動

```txt
sudo podman run --name mother_gift -d -p 9104:9104 -e DATA_SOURCE_NAME="exporter:Aa1234@(EMST-Test03:3306)/" prom/mysqld-exporter
```

找容器內部的ip

```txt
sudo podman inspect mother_gift | grep IPAddress
            "IPAddress": "10.88.2.37",
                    "IPAddress": "10.88.2.37"
```


docker run -d -p 9104:9104 --network my-mysql-network  -e DATA_SOURCE_NAME="exporter:Aa1234@(192.168.199.235:3306)/" prom/mysqld-exporter


要用這個IP去建立DB User

```txt
CREATE USER exporter@10.88.2.37 IDENTIFIED BY 'Aa1234' WITH MAX_USER_CONNECTIONS 3;
grant ALL PRIVILEGES on *.* to 'exporter'@'10.88.2.37'
```

先認識Bridge 

- https://www.cnblogs.com/bakari/p/10529575.html

Podman網路說明

- https://www.i4k.xyz/article/chenmozhe22/113941733

- https://blog.csdn.net/omaidb/article/details/121091789

- https://docs.podman.io/en/latest/markdown/podman-network-create.1.html

- https://podman.io/getting-started/



### 灌好系統後要做的事情

sudo dnf -y groupinstall "Development Tools"

- https://ciq.co/blog/top-10-things-to-do-after-rocky-linux-9-install/

### GitLab搬遷換主機要幹麻

先把資料壓縮起來
1. sudo tar -czvf 235opt.tar.gz opt/
把資料移出來
2. sudo scp 235opt.tar.gz root@192.168.199.234:/opt
把腳本移出來
3. scp docker-compose.yml SonarQube.yml 192.168.199.234:~
修改腳本內容的IP
4. vi docker-compose.yml / vi SonarQube.yml
5. 在開啟腳本就好了