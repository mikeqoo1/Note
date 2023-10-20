# GitLab 的啟動

這邊採用人家的腳本[GitHub 在這邊](https://github.com/sameersbn/docker-gitlab)

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
