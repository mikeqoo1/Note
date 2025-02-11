# 康 x 技能包

## 憑證問題

```bash
先把 IE 的憑證匯出來，??????.cer

上網 處理方法 For Ubuntu
sudo cp ??????.cer /etc/ssl/certs

先把 cer to crt
openssl x509 -in ??????..cer -out ??????.crt -inform DER

手動新增 CA 憑證
sudo cp ??????.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

npm 處理方法
npm config set cafile "/path/??????.cer"

snap 處理方法
openssl x509 -inform der -in ??????.cer -out xxxx.pem
sudo snap set system store-certs.cert1="$(cat /path/xxxx.pem)"

For Rocky/CentOS
sudo cp ??????.cer /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

For Docke 容器裡
cp ??????.cer ?????.crt /usr/local/share/ca-certificates/
cp ??????.cer ?????.crt /etc/ssl/certs/
update-ca-certificates
```

## 系統裝機手冊 2.0

```linux
sudo dnf update
sudo dnf install epel-release
sudo dnf install htop

遠端桌面選配安裝

先裝 GUI 桌面
dnf groupinstall "Server with GUI" -y
systemctl set-default graphical
reboot

再裝 xrdp 服務
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

## 安裝 MariaDB 10.5 10.6 10.11 LTS

sudo vi /etc/yum.repos.d/mariadb.repo

```ini
[mariadb] 
name = MariaDB 
baseurl = http://yum.mariadb.org/10.5/rhel9-amd64 
module_hotfixes=1 
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB 
gpgcheck=1
```

```ini
[mariadb] 
name = MariaDB 
baseurl = http://yum.mariadb.org/10.6/rhel9-amd64 
module_hotfixes=1 
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB 
gpgcheck=1
```

```ini
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.11/rhel9-amd64
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

設定檔複製到節點 2 節點 3 ip 名稱換一換

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
skip_character_set_client_handshake = 1   #跳過 mysql 登入時候的字符集參數設定 使用 Server 端的設定
binlog_format            = ROW
#binlog_format            = MIXED
# 基於語句紀錄： STATEMENT，只紀錄語句。該模式存在弊端，比如執行 "UPDATE students SET birth = now ();" 無法保存具体的時間戳記，若按照該語句進行還原準確性肯定出現問題。
# 基於行紀錄：ROW，只紀錄數據，即直接將數據存下来，但檔案大小較大。適合資料相對重要的場景。資料恢复時準確性的最高，但需要犧牲更多的硬碟空間。
# 混合模式： MIXED 系统自行判定該用哪個方式存
#MariaDB 5.5.x 默認 STATEMENT, 而 MariaDB 10.2.x 默認 MIXED
default-storage-engine   = innodb
innodb_autoinc_lock_mode = 2
bind-address             = 0.0.0.0

wait_timeout            = 86400   #24hr
interactive_timeout     = 86400
max_allowed_packet      = 1073741824 #1G
net_buffer_length       = 65536

general_log              = 1
general_log_file         = /var/lib/mysql/mariadb.log

slow_query_log           = 1 #0 = 關閉 1 = 打開
slow_query_log_file      = /var/lib/mysql/query_slow.log
long_query_time          = 0.1 #執行超過 0.1 秒

log-error                = /var/lib/mysql/error.log
log_bin_trust_function_creators = 1
log_bin                  = /var/lib/mysql/mariadb_bin.log
max_binlog_size          = 1073741824 #log 大小
sync_binlog              = 0 #設定是否啟動 binlog 即时同步硬碟功能，默認 0，由操作系统負責同步 log 到硬碟
expire_logs_days         = 3 #保留 3 天

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

關閉 SELINUX

vi /etc/selinux/config

```ini
SELINUX=disabled
```

第一台的啟動 sudo galera_new_cluster 其他 sudo systemctl start mariadb

需要改變存取目錄的話 要更改設定檔跟調整設定

先建立目錄 調整目錄權限 把原本的資料轉移到後來的目錄

```bash
sudo mkdir /home/Database
sudo chown -R mysql:mysql /home/Database/
sudo cp -a /var/lib/mysql/* /home/Database
```

```ini
# 修改my.cnf
datadir                 = /home/Database
```
解除資料夾在home目錄底下的設定

```bash
sudo vi /etc/systemd/system/mariadb.service.d/galera.conf
```

```ini
[Service]
TimeoutStartSec=0
ProtectHome=false
```

```bash
sudo systemctl daemon-reload
```

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

haproxy 檢查與重啟概念

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
# 1. 產生 private key
openssl genrsa -out gitlab.key 2048
# 2. 某某 vm 或服務 (例如:iis、apache) 產生 certificate signing request (CSR)
openssl req -new -key gitlab.key -out gitlab.csr
# 3. 作簽章 (用 private key 對 CSR 作簽章)
openssl x509 -req -days 3650 -in gitlab.csr -signkey gitlab.key -out gitlab.crt
# 4. 產生 stronger DHE parameters 
openssl dhparam -out dhparam.pem 2048
sudo mkdir -p /srv/docker/gitlab/gitlab/certs # 這是 host 的目錄喔，會對到 gitlab 的 /home/git/data
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

## 母親節禮物

先啟動

```txt
sudo podman run --name mother_gift -d -p 9104:9104 -e DATA_SOURCE_NAME="exporter:Aa1234@(EMST-Test03:3306)/" prom/mysqld-exporter
```

找容器內部的 ip

```txt
sudo podman inspect mother_gift | grep IPAddress
            "IPAddress": "10.88.2.37",
                    "IPAddress": "10.88.2.37"
```


docker run -d -p 9104:9104 --network my-mysql-network  -e DATA_SOURCE_NAME="exporter:Aa1234@(192.168.199.235:3306)/" prom/mysqld-exporter


要用這個 IP 去建立 DB User

```txt
CREATE USER exporter@10.88.2.37 IDENTIFIED BY 'Aa1234' WITH MAX_USER_CONNECTIONS 3;
grant ALL PRIVILEGES on *.* to 'exporter'@'10.88.2.37'
```

先認識 Bridge 

- https://www.cnblogs.com/bakari/p/10529575.html

Podman 網路說明

- https://www.i4k.xyz/article/chenmozhe22/113941733

- https://blog.csdn.net/omaidb/article/details/121091789

- https://docs.podman.io/en/latest/markdown/podman-network-create.1.html

- https://podman.io/getting-started/



## 灌好系統後要做的事情

sudo dnf -y groupinstall "Development Tools"

- https://ciq.co/blog/top-10-things-to-do-after-rocky-linux-9-install/

## GitLab 搬遷換主機要幹麻

先把資料壓縮起來
1. sudo tar -czvf 235opt.tar.gz opt/
把資料移出來
2. sudo scp 235opt.tar.gz root@192.168.199.234:/opt
把腳本移出來
3. scp docker-compose.yml SonarQube.yml 192.168.199.234:~
修改腳本內容的 IP
4. vi docker-compose.yml / vi SonarQube.yml
5. 在開啟腳本就好了

## Rocky 9 安裝信箱功能

1. sudo dnf install s-nail
2. sudo dnf install postfix
3. sudo systemctl restart postfix

另外有一個郵件檢查功能可以關掉, 有時候出現這個的時候
You have new mail in /var/spool/mail/xxx

可以用 cat /var/spool/mail/xxx 來查看, 也可以關掉但是一定要用 root

1. echo "unset MAILCHECK">> /etc/profile
2. source /etc/profile

## Rocky 安裝 AD 服務

1. sudo dnf -y install realmd sssd oddjob oddjob-mkhomedir adcli samba-common-tools krb5-workstation

2. sudo vi /etc/krb5.conf

```txt
    default_tkt_enctypes = RC4-HMAC, DES-CBC-CRC, DES3-CBC-SHA1, DES-CBC-MD5
    default_tgs_enctypes = RC4-HMAC, DES-CBC-CRC, DES3-CBC-SHA1, DES-CBC-MD5
```

3. Open Firewall

```bash
sudo firewall-cmd --zone=public --permanent --add-port=53/tcp
sudo firewall-cmd --zone=public --permanent --add-port=53/udp

# LDAP
sudo firewall-cmd --zone=public --permanent --add-port=389/tcp
sudo firewall-cmd --zone=public --permanent --add-port=389/udp

# Samba
sudo firewall-cmd --zone=public --permanent --add-port=445/tcp
sudo firewall-cmd --zone=public --permanent --add-port=445/udp

# Kerberos
sudo firewall-cmd --zone=public --permanent --add-port=88/tcp
sudo firewall-cmd --zone=public --permanent --add-port=88/udp

sudo firewall-cmd --zone=public --permanent --add-port=464/tcp
sudo firewall-cmd --zone=public --permanent --add-port=464/udp

# LDAP Global Catalog
sudo firewall-cmd --zone=public --permanent --add-port=3268/tcp

# NTP
sudo firewall-cmd --zone=public --permanent --add-port=123/tcp
sudo firewall-cmd --reload
```

4. sudo realm join concords.com.tw --user=(網管員編) (輸入密碼)網管員編密碼

5. sudo vi /etc/krb5.conf

```txt
    #default_tkt_enctypes = RC4-HMAC, DES-CBC-CRC, DES3-CBC-SHA1, DES-CBC-MD5
    #default_tgs_enctypes = RC4-HMAC, DES-CBC-CRC, DES3-CBC-SHA1, DES-CBC-MD5
```

6. sudo vi /etc/sssd/sssd.conf

```txt
    use_fully_qualified_names = False
```

7. sudo systemctl restart sssd

8. sudo realm deny --all

9. sudo realm permit -g 資訊部

10. 如果連上AD但無法登入時檢查這兩個服務是否正常啟動

```bash
sudo systemctl status sssd-kcm.socket
sudo systemctl status sssd-kcm.service
```

11. 若登入無法自動創建家目錄, 則加入以下設定

``` bash
sudo vi /etc/pam.d/sshd
```

12. pam_selinux.so close should be the first session rule

```bash
session    required     pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

## Rocky 資料庫裝 AD 服務

1. sudo dnf install gcc pam-devel wget

2. wget <https://raw.githubusercontent.com/MariaDB/server/10.11/plugin/auth_pam/mapper/pam_user_map.c>

```txt
這邊要對應資料庫版本
https://github.com/MariaDB/server 可以去官方的庫抓檔案 記得版本要選對
```

3. sed -ie 's/config_auth_pam/plugin_auth_common/' pam_user_map.c

4. gcc -I/usr/include/mysql/mysql pam_user_map.c -shared -lpam -fPIC -o pam_user_map.so

```txt
如果出現編譯錯誤 就自己去/usr/include/mysql/mysql加入檔案plugin_auth_common.h
```

```c++
#ifndef MYSQL_PLUGIN_AUTH_COMMON_INCLUDED
/* Copyright (c) 2010, 2023, Oracle and/or its affiliates.
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License, version 2.0,
   as published by the Free Software Foundation.
   This program is also distributed with certain software (including
   but not limited to OpenSSL) that is licensed under separate terms,
   as designated in a particular file or component or in included license
   documentation.  The authors of MySQL hereby grant you an additional
   permission to link the program and your derivative works with the
   separately licensed software that they have included with MySQL.
   Without limiting anything contained in the foregoing, this file,
   which is part of C Driver for MySQL (Connector/C), is also subject to the
   Universal FOSS Exception, version 1.0, a copy of which can be found at
   http://oss.oracle.com/licenses/universal-foss-exception.
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License, version 2.0, for more details.
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */
/**
  @file include/mysql/plugin_auth_common.h
  This file defines constants and data structures that are the same for
  both client- and server-side authentication plugins.
*/
#define MYSQL_PLUGIN_AUTH_COMMON_INCLUDED
/** the max allowed length for a user name */
#define MYSQL_USERNAME_LENGTH 96
/**
  return values of the plugin authenticate_user() method.
*/
/**
  Authentication failed, plugin internal error.
  An error occurred in the authentication plugin itself.
  These errors are reported in table performance_schema.host_cache,
  column COUNT_AUTH_PLUGIN_ERRORS.
*/
#define CR_AUTH_PLUGIN_ERROR 3
/**
  Authentication failed, client server handshake.
  An error occurred during the client server handshake.
  These errors are reported in table performance_schema.host_cache,
  column COUNT_HANDSHAKE_ERRORS.
*/
#define CR_AUTH_HANDSHAKE 2
/**
  Authentication failed, user credentials.
  For example, wrong passwords.
  These errors are reported in table performance_schema.host_cache,
  column COUNT_AUTHENTICATION_ERRORS.
*/
#define CR_AUTH_USER_CREDENTIALS 1
/**
  Authentication failed. Additionally, all other CR_xxx values
  (libmysql error code) can be used too.
  The client plugin may set the error code and the error message directly
  in the MYSQL structure and return CR_ERROR. If a CR_xxx specific error
  code was returned, an error message in the MYSQL structure will be
  overwritten. If CR_ERROR is returned without setting the error in MYSQL,
  CR_UNKNOWN_ERROR will be user.
*/
#define CR_ERROR 0
/**
  Authentication (client part) was successful. It does not mean that the
  authentication as a whole was successful, usually it only means
  that the client was able to send the user name and the password to the
  server. If CR_OK is returned, the libmysql reads the next packet expecting
  it to be one of OK, ERROR, or CHANGE_PLUGIN packets.
*/
#define CR_OK -1
/**
  Authentication was successful.
  It means that the client has done its part successfully and also that
  a plugin has read the last packet (one of OK, ERROR, CHANGE_PLUGIN).
  In this case, libmysql will not read a packet from the server,
  but it will use the data at mysql->net.read_pos.
  A plugin may return this value if the number of roundtrips in the
  authentication protocol is not known in advance, and the client plugin
  needs to read one packet more to determine if the authentication is finished
  or not.
*/
#define CR_OK_HANDSHAKE_COMPLETE -2
/**
  Authentication was successful with limited operations.
  It means that the both client and server side plugins decided to allow
  authentication with very limited operations ALTER USER to do registration.
*/
#define CR_OK_AUTH_IN_SANDBOX_MODE -3
/**
Flag to be passed back to server from authentication plugins via
authenticated_as when proxy mapping should be done by the server.
*/
#define PROXY_FLAG 0
/*
  We need HANDLE definition if on Windows. Define WIN32_LEAN_AND_MEAN (if
  not already done) to minimize amount of imported declarations.
*/
#if defined(_WIN32) && !defined(MYSQL_ABI_CHECK)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif
struct MYSQL_PLUGIN_VIO_INFO {
  enum {
    MYSQL_VIO_INVALID,
    MYSQL_VIO_TCP,
    MYSQL_VIO_SOCKET,
    MYSQL_VIO_PIPE,
    MYSQL_VIO_MEMORY
  } protocol;
  int socket; /**< it's set, if the protocol is SOCKET or TCP */
#if defined(_WIN32) && !defined(MYSQL_ABI_CHECK)
  HANDLE handle; /**< it's set, if the protocol is PIPE or MEMORY */
#endif
};
/* state of an asynchronous operation */
enum net_async_status {
  NET_ASYNC_COMPLETE = 0,
  NET_ASYNC_NOT_READY,
  NET_ASYNC_ERROR,
  NET_ASYNC_COMPLETE_NO_MORE_RESULTS
};
/**
  Provides plugin access to communication channel
*/
typedef struct MYSQL_PLUGIN_VIO {
  /**
    Plugin provides a pointer reference and this function sets it to the
    contents of any incoming packet. Returns the packet length, or -1 if
    the plugin should terminate.
  */
  int (*read_packet)(struct MYSQL_PLUGIN_VIO *vio, unsigned char **buf);
  /**
    Plugin provides a buffer with data and the length and this
    function sends it as a packet. Returns 0 on success, 1 on failure.
  */
  int (*write_packet)(struct MYSQL_PLUGIN_VIO *vio, const unsigned char *packet,
                      int packet_len);
  /**
    Fills in a MYSQL_PLUGIN_VIO_INFO structure, providing the information
    about the connection.
  */
  void (*info)(struct MYSQL_PLUGIN_VIO *vio,
               struct MYSQL_PLUGIN_VIO_INFO *info);
  /**
    Non blocking version of read_packet. This function points buf to starting
    position of incoming packet. When this function returns NET_ASYNC_NOT_READY
    plugin should call this function again until all incoming packets are read.
    If return code is NET_ASYNC_COMPLETE, plugin can do further processing of
    read packets.
  */
  enum net_async_status (*read_packet_nonblocking)(struct MYSQL_PLUGIN_VIO *vio,
                                                   unsigned char **buf,
                                                   int *result);
  /**
    Non blocking version of write_packet. Sends data available in pkt of length
    pkt_len to server in asynchronous way.
  */
  enum net_async_status (*write_packet_nonblocking)(
      struct MYSQL_PLUGIN_VIO *vio, const unsigned char *pkt, int pkt_len,
      int *result);
} MYSQL_PLUGIN_VIO;
#endif
```

5. sudo install --mode=0755 pam_user_map.so /lib64/security/

6. INSTALL SONAME 'auth_pam'; 這段要進資料庫輸入

7. sudo vi /etc/security/user_map.conf

```txt
@samusers: misuser
```

8. sudo vi /etc/pam.d/mysqld

```txt
auth required pam_sss.so
auth required pam_user_map.so debug
account required pam_permit.so
```

9. 進去資料庫輸入

```sql
CREATE USER 'misuser'@'%' IDENTIFIED BY 'misuser';
GRANT SELECT ON *.* TO 'misuser'@'%' ;
CREATE USER ''@'%' IDENTIFIED VIA pam USING 'mysqld';
GRANT PROXY ON 'misuser'@'%' TO ''@'%';
```
