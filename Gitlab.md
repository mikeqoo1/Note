# GitLab 的啟動

這邊採用人家的腳本 [GitHub 在這邊](https://github.com/sameersbn/docker-gitlab)

記得要把本地資料夾建好
- /opt/redis 
- /opt/postgresql
- /opt/gitlab

腳本裡面也需要更改這些東西

```txt
ports:
    - "30001:80"
    - "30023:22"
    - "30444:443"
- GITLAB_HOST=192.168.199.235
- GITLAB_PORT=30001
- GITLAB_SSH_PORT=30023
```

GitLab 的備份如下

```txt
- GITLAB_BACKUP_SCHEDULE=daily
- GITLAB_BACKUP_TIME=01:00
```

[backups 的說明](https://github.com/sameersbn/docker-gitlab#maintenance)

# GitLab-Runner 的啟動

```txt
sudo docker run -d --name gitlab-runner-docker --restart always -v /opt/gitlab-runner/config:/etc/gitlab-runner -v /var/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:latest
```

# GitLab-Runner 管理 註冊

憑證管理
1. docker cp FG4H1FT922900264.crt gitlab-runner-docker:/etc/ssl/certs
2. docker cp certificate.crt gitlab-runner-docker:/etc/ssl/certs
3. 記得要重起整個 Docker 服務 systemctl  restart  docker.service 

先進去
4. sudo docker exec -it  gitlab-runner-docker /bin/bash

在註冊
5. gitlab-runner register

# GitLab CI/CD 製造 C# 的環境

1. sudo docker pull mono:latest

2. sudo docker run -d --name cicdmono -v /home/windowsmono:/tmp/host -it mono bash

3. 把憑證丟進去 sudo docker cp certificate.crt cicdmono:/usr/local/share/ca-certificates/

4. 把憑證丟進去 sudo docker cp FG4H1FT922900264.crt cicdmono:/usr/local/share/ca-certificates/

5. update-"/var/run/docker.sock:/var/run/docker.sock"ca-certificates

6. sudo docker exec -it cicdmono /bin/bash

7. cp FG4H1FT922900264.crt /etc/ssl/certs

8. cp certificate.crt /etc/ssl/certs

9. apt-get update

10. apt-get install -y openjdk-11-jdk

11. apt-get install -y wget

12. apt-get install -y unzip

13. mkdir scanner && cd scanner

14. wget https://github.com/SonarSource/sonar-scanner-msbuild/releases/download/5.15.0.80890/sonar-scanner-msbuild-5.15.0.80890-net46.zip (用本地複製到容器裡)

15. unzip scanner/sonar-scanner-msbuild-5.15.0.80890-net46.zip

16. chmod +x sonar-scanner-4.8.1.3023/bin/sonar-scanner

[文章參考](https://dennys.github.io/en/doc/devops/gitlab-sonarqube-integration-dotnet/)

[文章參考](https://dennys.github.io/en/doc/devops/sonarqube-mono-dotnet4-integration/)

# C# .Net Core 的源碼掃描

235 本機裝這些套件後, 讓 Runner 用 SSH 的方法連線執行

套件安裝如下

```bash
sudo dnf install dotnet-host
sudo dnf install dotnet-sdk-8.0 
dotnet tool install --global dotnet-sonarscanner
export PATH=\"$PATH:$HOME/.dotnet/tools\""
```

GitLab Runner 要改成用 ssh 的方式 Like this

```bash
[[runners]]
  name = "shellPushServer"
  url = "http://GitLabIP:30001/"
  id = 25
  token = "專案偷肯"
  token_obtained_at = 2024-03-11T10:36:36Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "ssh"
  [runners.cache]
    MaxUploadedArchiveSize = 0
  [runners.ssh]
    user = "主機帳號"
    password = "主機密碼"
    host = "主機IP"
    port = "22"
    identity_file = "/主機帳號/.ssh/id_rsa"
```
# GitLab CI Docker in Docker

萬一遇到 Error during connect: Post http://docker:2375/v1.40/auth: dial tcp: lookup docker on x.x.x.x:53: no such host 的問題

需要在 gitlab runner 的設定檔加上"/var/run/docker.sock:/var/run/docker.sock"

```bash
[[runners]]
  name = "max"
  url = "https://max.lv"
  id = 3
  token = "glrt-Pnz4_jx3_reTXZ1B"
  token_obtained_at = 2024-04-02T11:11:56Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "docker:24.0.5"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]   <---- 這邊
    shm_size = 0
    network_mtu = 0
```

# GitLab-Runner 的升級

```bash
1. 先拉最新的 images

sudo docker pull gitlab/gitlab-runner:latest

2.停掉舊容器

sudo docker stop gitlab-runner-docker

3. 刪掉舊容器（不會刪你的 config，因為 config 在 host volume）

sudo docker rm gitlab-runner-docker

4. 用同樣的方式重建

sudo docker run -d --name gitlab-runner-docker --restart always\
-v /opt/gitlab-runner/config:/etc/gitlab-runner\
-v /var/run/docker.sock:/var/run/docker.sock\
gitlab/gitlab-runner:latest

5. 匯入 235 的 https 自簽憑證

6. 匯入阿康防火牆CA

```