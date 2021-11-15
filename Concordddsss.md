# 康x技能包

## 憑證問題

```bash
先把IE的憑證匯出來, ??????.cer

上網 處理方法
sudo cp ??????.cer /etc/ssl/certs

npm 處理方法
npm config set cafile "/path/??????.cer"

snap 處理方法
openssl x509 -inform der -in ??????.cer -out xxxx.pem
sudo snap set system store-certs.cert1="$(cat /path/xxxx.pem)"
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

sudo dnf install mariadb-server mariadb
sudo systemctl start mariadb
sudo systemctl status mariadb
sudo mariadb-secure-installation

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
datadir                  = /database/mariadb
binlog_format            = ROW
default-storage-engine   = innodb
innodb_autoinc_lock_mode = 2
bind-address             = 0.0.0.0


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
wsrep_node_address       = "node1"
```

防火牆開啟

```ini
sudo firewall-cmd –permanent –zone=public –add-port=3306/tcp
sudo firewall-cmd –permanent –zone=public –add-port=4567/tcp
sudo firewall-cmd –permanent –zone=public –add-port=4568/tcp
sudo firewall-cmd –permanent –zone=public –add-port=4444/tcp
sudo firewall-cmd –permanent –zone=public –add-port=4567/udp
sudo firewall-cmd –reload
```

關閉SELINUX

vi /etc/selinux/config

```ini
SELINUX=diabled
```

第一台的啟動 sudo galera_new_cluster 其他 sudo systemctl start mariadb
