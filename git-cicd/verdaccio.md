# 私有NPM倉庫建立 (verdaccio)

mkdir -p ~/verdaccio/storage
mkdir -p ~/verdaccio/config

touch ~/verdaccio/storage/htpasswd
sudo chown 1003:1003 ~/verdaccio/storage/htpasswd
chmod -R 777 ~/verdaccio/storage

把你的 config.yaml 放到 ~/verdaccio/config/config.yaml

config.yaml 在阿康專區 Verdaccio-config.yaml

docker-compose.yml 在阿康專區 Verdaccio-DockerCompose.yml

~/verdaccio/
├── docker-compose.yml
├── .env
├── storage/
└── config/
    └── config.yaml

加一個 .env 檔案，讓 UID:GID 可以自動帶入（Docker Compose 支援 .env）

建立 .env 檔，內容：

```txt
UID=1000
GID=1000
```

查自己 UID/GID：

```bash
id -u
id -g
```

### 啟動

podman compose -f verdaccio-docker-compose.yml up -d

### 關閉

podman compose -f verdaccio-docker-compose.yml down

### 上傳 package

```bash
npm publish --registry http://192.168.199.235:4873/
```

### 刪除 package

```bash
npm unpublish @110084/cgva-addon --force --registry http://192.168.199.235:4873
```
