# 用指令安裝私有倉庫

sudo docker run -d \
    -p 5000:5000 \
    -v /opt/data/registry:/var/lib/registry \                                 # 把資料留本地
    -v /opt/data/registry/srv-config.yml:/etc/docker/registry/config.yml \    # 把 config 抓到本地方便設定
    --restart=always --name mike-registry registry:latest

# srv-config.yml  (要先在 /opt/data/registry 建立)

```txt
version: 0.1
log:
  fields:
    service: registry
storage:
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

# 用指令安裝 docker 倉庫 Web UI

sudo docker run -d \
    -p 8080:8080 \
    -v /opt/data/registry/web-config.yml:/conf/config.yml \
    --restart=always --name mike-registry-web \
   hyper/docker-registry-web

# web-config.yml  (要先在 /opt/data/registry 建立)

```txt
registry:
  # Docker registry url
  url: http://192.168.199.235:5000/v2
  # Docker registry fqdn
  name: localhost:5000
  # To allow image delete, should be false
  readonly: false
  auth:
    # Disable authentication
    enabled: false
```
