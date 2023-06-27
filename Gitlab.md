sudo docker docker run -d --name gitlab-runner-mike --restart always -v /opt/gitlab-runner/config:/etc/gitlab-runner 
-v /opt/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:v15.0.2

docker run -d --name gitlab-runner-docker --restart always -v /opt/gitlab-runner/config:/etc/gitlab-runner -v /var/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:latest

GitLab的備份.....
gitlab:backup:restore 


###### GitRunnerConfig

1. sudo docker exec -it  3623b7e33b35 /bin/bash

2. gitlab-runner register


```config
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "trading_ci/cd"
  url = "http://192.168.199.235:30001/"
  token = "QB7HTzB6iwDca1EXPggs"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0

[[runners]]
  name = "crcft"
  url = "http://192.168.199.235:30001/"
  token = "ThXeDVaz8zayLEUhrDtJ"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
```
