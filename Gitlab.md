sudo docker docker run -d --name gitlab-runner-mike --restart always -v /opt/gitlab-runner/config:/etc/gitlab-runner 
-v /opt/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:v15.0.2



docker run -d --name gitlab-runner-docker --restart always -v /opt/gitlab-runner/config:/etc/gitlab-runner -v /var/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:latest













###### GitRunnerConfig



concurrent = 6
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "genZ"
  url = "http://192.168.200.54:30000/"
  token = "XFsHgWz4ZYrcETxVoYrM"
  executor = "docker"
  clone_url = "http://192.168.200.54:30000/"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    pull_policy = ["if-not-present"]
    shm_size = 0

[[runners]]
  name = "gitlab_runner_docker"
  url = "http://192.168.200.54:30000/"
  token = "WCHa4Z2nns7bxvyMh7iN"
  executor = "docker"
  clone_url = "http://192.168.200.54:30000/"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "106061/myimage:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0

[[runners]]
  name = "crcft_runner"
  url = "http://192.168.200.54:30000/"
  token = "ib3wxe_heJFRriZGMTZM"
  executor = "docker"
  clone_url = "http://192.168.200.54:30000/"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
  [runners.custom]
    run_exec = ""

[[runners]]
  name = "crcft_c_runner"
  url = "http://192.168.200.54:30000/"
  token = "RtD6-JePjyvo5WyBaFRu"
  executor = "shell"
  clone_url = "http://192.168.200.54:30000/"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.custom]
    run_exec = ""

[[runners]]
  name = "TradingSystemRunner"
  url = "http://192.168.200.54:30000/"
  clone_url = "http://192.168.200.54:30000/"
  token = "J8hKBZA_ad7sKrCJ9tue"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0


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
