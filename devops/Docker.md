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

/var/lib/docker/overlay2 目錄下的大檔案是Docker映像或容器的圖層（layers）。這些層可能是由於先前的Docker容器未正確清理或刪除，導致殘留的層檔案。

```bash
記得切換成root
cd /var/lib/docker
du -h --max-depth=1
# 執行後發現確實是overlay2下佔用最大，這裡有些人也可能是volumes佔用很大，根據情況繼續往下找

du -h --max-depth=1 --threshold=5G # 只列出大於5G



# diff 資料夾： diff 資料夾是唯讀的檔案系統層，它包含了Docker映像的變更內容。當您對容器進行修改或新增檔案時，這些變更會被記錄在 diff 資料夾中。每個Docker映像都有一個對應的 diff 資料夾，用於儲存與基礎映像的差異。

# merged 資料夾： merged 資料夾是一個可讀寫的檔案系統層，它是由基礎鏡像和 diff 資料夾合併而成的。當您啟動一個Docker容器時， merged 資料夾中的內容將作為容器的檔案系統。這個資料夾是容器運行時的可寫入層，您可以在容器中對文件進行修改或添加新文件，這些修改將儲存在 merged 資料夾中。

在針對裡面的內容去判斷要不要刪掉

https://blog.csdn.net/weixin_43756185/article/details/132709101
```

```bash
# 查看images使用狀況
docker system df -v
# 清理硬碟 刪掉關閉的容器 沒用的資料和網路 以及沒tag的image
docker system prune
# 把没有容器使用 Docker images 都刪掉。注意，這两個命令會把你暫時關閉的容器，還有暫時没有用到的 Docker images 都刪掉了
docker system prune -a
```

```bash
這個指令將刪除 /var/lib/docker/containers/ 目錄下的容器日誌檔案。
sudo find /var/lib/docker/containers/ -name "*-json.log" -type f -delete 1

docker日誌linux中由服務產生的日誌（重要）這個指令將直接列出linux中大於100M的檔案。
find / -size +100M -type f 1
```

# 打包自己建立的docker容器

先把容器轉換為 Image 並且取名是我的 docker hub 專案名稱

1. sudo docker commit 5f373bc1348c 106061/almalinux9andnvm:latest

確認 images

2. sudo docker images

3. sudo docker push 106061/almalinux9andnvm:latest

# Docker Volumes 轉移

最佳方案：改 Docker 的 data-root 到 /data 在沒有任何容器的時候使用 這樣不會影響其他設定 裝新機器的時候最適合

```txt
這會把 /var/lib/docker 整個搬走（包含 image、overlay2、build cache、volumes），通常最能省 /root/系統碟。
```

步驟很簡單

1. Stops docker
2. Rsync /var/lib/docker -> /data/docker
3. Configure /etc/docker/daemon.json with "data-root"
4. Start docker and verify

腳本在 move_docker_volumes_to_data.sh

