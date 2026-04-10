# Podman

1. 安裝方法

```bash
# Ubuntu / Debian
sudo apt update
sudo apt install -y podman

# CentOS / AlmaLinux / RHEL
sudo dnf install -y podman
```

2. 操作指令跟 Docker 一樣

功能 | Podman 指令
拉取 image | podman pull nginx
查看本地 images | podman images
執行 container | podman run -d -p 8080:80 nginx
查看執行中的 containers | podman ps
查看所有 containers | podman ps -a
停止 container | podman stop <container-id>
移除 container | podman rm <container-id>
移除 image | podman rmi <image-id>
進到 container 裡面 | podman exec -it <container-id> bash

3. Rootless 模式（Podman 特有）

Podman 最強的一點是它 可以不用 root 權限跑 container！

只要你是一般使用者登入，就可以直接跑 podman，不用 sudo。 （除非你需要綁定 1024 以下的port）

4. Podman 的 Pod（進階）

Podman 支援「Pod」的概念，可以把多個 container 放在同一個 Network Namespace 裡跑。

6. Podman Compose

```bash
sudo dnf install -y podman-compose
```

7. 範例

whoami：會回你 IP、headers，超適合測試 proxy path

nginx：靜態頁面 web server，你可以放自己的 HTML 測樣式轉發

httpbin：HTTP 測試利器（測 GET/POST/headers/redirect）


測試網址 | 功能
http://192.168.199.250:8456/ | → whoami (default)
http://192.168.199.250:8456/nginx | → nginx 的 HTML 頁
http://192.168.199.250:8456/httpbin | → httpbin 工具 (e.g. /httpbin/get)
