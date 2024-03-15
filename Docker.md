# 更新 Docker-compose 的容器
更新用Docker-compose部署的應用

第一步 进入到你docker-compose所在的文件夹下，执行
docker compose pull

第二步 重启你的容器
docker compose up -d --remove-orphans

第三步 (可选) 删除掉旧的镜像
docker image prune

# Docker /var/lib/docker/overlay2 佔用太多空間

overlay 分區是 Docker 的虛擬文件系統

```bash
# 查看images使用狀況
docker system df -v
# 清理硬碟 刪掉關閉的容器 沒用的資料和網路 以及沒tag的image
docker system prune
# 把没有容器使用 Docker images 都刪掉。注意，這两個命令會把你暫時關閉的容器，還有暫時没有用到的 Docker images 都刪掉了
docker system prune -a
```
