# 佈署TiDB單機模擬集群的樣子

1. 先安裝TiUP, TiUP是TiDB 4.0 版本引入的集群維運工具

```bash
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
```

設置環境變數

```bash
source .bash_profile
```

確認指令

```bash
tiup cluster
```

2. 設定MaxSessions, 改完要重新啟動service sshd restart, 改這個是為了防止多個程式scp文件時ssh登錄超過數量限制

```bash
vi  /etc/ssh/sshd_confi
----------------------
MaxSessions=20
```

3. 產生佈署文件

tuip cluster template > topo.yaml

```yaml
# # Global variables are applied to all deployments and used as the default value of
# # the deployments if a specific deployment value is missing.
global:
 user: "tidb" #會自動產生不用管
 ssh_port: 22
 deploy_dir: "/tidb-deploy" #放執行檔(PD, TiKV, TiDB...)的地方
 data_dir: "/tidb-data" #放資料的地方

# # Monitored variables are applied to all the machines.
monitored:
 node_exporter_port: 9100
 blackbox_exporter_port: 9115

server_configs:
 tidb:
   log.slow-threshold: 300
 tikv:
   readpool.storage.use-unified-pool: false
   readpool.coprocessor.use-unified-pool: true
 pd:
   replication.enable-placement-rules: true
   replication.location-labels: ["host"]
 tiflash:
   logger.level: "info"

pd_servers:
 - host: 192.168.xxx.xxx

tidb_servers:
 - host: 192.168.xxx.xxx

tikv_servers:
 - host: 192.168.xxx.xxx
   port: 20160
   status_port: 20180
   config:
     server.labels: { host: "test-kv-1" }

 - host: 192.168.xxx.xxx
   port: 20161
   status_port: 20181
   config:
     server.labels: { host: "test-kv-2" }

 - host: 192.168.xxx.xxx
   port: 20162
   status_port: 20182
   config:
     server.labels: { host: "test-kv-3" }

tiflash_servers:
 - host: 192.168.xxx.xxx

monitoring_servers:
 - host: 192.168.xxx.xxx

grafana_servers:
 - host: 192.168.xxx.xxx
```

4. 佈署

```bash
tiup cluster deploy tidb-test v5.4.0 ./topo.yaml --user root -p
```

5. 查看TiUP管理的集群

```bash
tiup cluster list
```

6. 查看剛剛佈署好tidb-test

```bash
tiup cluster display tidb-test
```



