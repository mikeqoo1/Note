# Podman

podman run \
  --name gitlabtest \
  --hostname 192.168.199.236 \
  --publish 30443:443 \
  --publish 30000:80 \
  --publish 30022:22 \
  --volume /srv/gitlab/config:/etc/gitlab:Z \
  --volume /srv/gitlab/logs:/var/log/gitlab:Z \
  --volume /srv/gitlab/data:/var/opt/gitlab:Z \
  docker.io/gitlab/gitlab-ee


export GITLAB_HOME=/opt/gitlab
sudo mkdir -p $GITLAB_HOME
sudo mkdir $GITLAB_HOME/data $GITLAB_HOME/config $GITLAB_HOME/logs
podman run --detach \
  --privileged \
  --hostname 192.168.199.234 \
  --publish 30443:443 \
  --publish 30000:80 \
  --publish 30022:22 \
  --name gitlab \
  --volume /opt/gitlab/config:/etc/gitlab \
  --volume /opt/gitlab/logs:/var/log/gitlab \
  --volume /opt/gitlab/data:/var/opt/gitlab \
  gitlab/gitlab-ee:latest





https://dic.vbird.tw/network_project/zunit12.php
https://ithelp.ithome.com.tw/articles/10241665
https://python.iitter.com/other/267537.html
https://forum.gitlab.com/t/podman-gitlab-ce-installation-fails-waiting-on-postgresql/56828
https://gist.github.com/pichuang/7ce8be00c3de3f51e5c8db0689f1e08a