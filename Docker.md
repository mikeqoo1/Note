2、更新用Docker-compose部署的应用
很简单，只要三步。

第一步
进入到你docker-compose所在的文件夹下，执行

docker compose pull

第二步
重启你的容器

docker compose up -d --remove-orphans

第三步（可选）
删除掉旧的镜像

docker image prune 