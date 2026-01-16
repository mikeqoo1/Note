# 真實使用情境

![alt text](使用情境.png)

```txt
[A Host]
 ├─ pmm-agent           ← 裝在 host（只裝一次）
 │   ├─ node_exporter   ← 主機 CPU / RAM / Disk
 │   ├─ mysqld_exporter / postgres_exporter / redis_exporter
 │   └─ 負責把資料送到 PMM Server
 │
 ├─ MariaDB container
 ├─ Redis container
 └─ PostgreSQL container

[PMM Server] (Docker)
 └─ 收 metrics + UI
```

## 234 (A主機的問題)

1) 安裝 pmm-agent

```bash
sduo yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm
sduo percona-release enable pmm3-client release
sduo yum install -y pmm-client
```

2) 因為 pmm-agent 的 7777 被佔用所以要去修改然後重新設定

```bash
sudo vi /usr/local/percona/pmm/config/pmm-agent.yaml

改port

sudo pmm-agent setup \
  --config-file=/usr/local/percona/pmm/config/pmm-agent.yaml \
  --server-address=192.168.199.234:18443 \
  --server-username=admin \
  --server-password='Aa123456' \
  --server-insecure-tls \
  --force

sudo systemctl restart pmm-agent
```

3) 因為改 Port 所以 pmm-admin 指令需要修改增加 --pmm-agent-listen-port

```bash
sudo pmm-admin add mysql   --server-url=https://admin:Aa123456@192.168.199.234:18443   --server-insecure-tls   --pmm-agent-listen-port=17777   --username=crcft   --password='Aa1234'   --host=192.168.199.234   --port=3306   --service-name=mariadb-234   --query-source=slowlog
```

4) 同一台主機 不同容器的加入方式

![alt text](不同容器.png)

5) 使用容器的 IP 來加入節點

```bash
sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' noco_new_db

sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' hedgedoc-database-1

sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql
```

6) 建立資料庫帳號

```bash
docker exec -it noco_new_db psql -U noco_appsmith -d app_data

CREATE USER pmm WITH PASSWORD 'StrongPMMpass!';

GRANT pg_monitor TO pmm;
```

7) noco-db 加入監控

```bash
sudo pmm-admin add postgresql \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=172.17.0.6 \
  --port=5432 \
  --service-name=postgres-noco
```

8) hedgedoc 加入監控

```bash
sudo pmm-admin add postgresql \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=172.19.0.2 \
  --port=5432 \
  --service-name=postgres-hedgedoc-ip
```

9) mysql-apitable 加入監控

```bash
sudo pmm-admin add mysql \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --server-insecure-tls \
  --pmm-agent-listen-port=17777 \
  --username=pmm \
  --password='StrongPMMpass!' \
  --host=172.27.0.3 \
  --port=3306 \
  --service-name=mysql-apitable-3306
```

10) 驗證

```bash
sudo pmm-admin list \
  --server-url=https://admin:Aa123456@192.168.199.234:18443 \
  --pmm-agent-listen-port=17777 \
  --server-insecure-tls
```

![alt text](驗證.png)

