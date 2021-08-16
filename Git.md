# Git

## 壓縮合併 (--squash)

```git
把多個commit點,合併成一個點,再merge進主要分支
git merge --squash 加上這個標籤，就是把 分支上的修改壓縮成一個commit點再合併。
將 branch 上的所有改動壓成一次 commit 再嘗試合併現在的分支。這樣我們還需要用一次 git commit 來提交，這时分支就可以變得很乾淨了
```

## git reset

```git
回覆上一個動作
git reset HEAD^ --soft 取消剛剛的commit但保留修改過的檔案
git reset HEAD^ --hard 取消剛剛的 commit，回到再上一次 commit的 乾淨狀態
```

## 查看user和email

```git
git config user.name
git config user.email

要修改的話, 在後面加上user name 或 e-mail 就好

加 --global 就是全域設定,所有專案都有效,不然只會在該專案生效
git config --global user.name "your name"
git config --global user.email "your email"
```

## 同步當初 fork 的專案

```git
git remote add 分支名稱 原作者的.git專案

git fetch 剛剛創的分支名稱
```

## git rebase 衝突該怎做？

```git
git checkout 要 rebase 的分支

git rebase (devel/master)分支

衝突發生時, 解决衝突後 add 更改後的文件

git add 解決完衝突的文件

不用commit, 繼續rebase

git rebase --continue
```

## Git 更換遠端伺服器倉庫網址URL

1.確認目前Git遠端伺服器網址： git remote -v

```git
  git remote -v
  origin  https://github.com/USERNAME/REPOSITORY.git (fetch)
  origin  https://github.com/USERNAME/REPOSITORY.git (push)
```

2.更換Git遠端伺服器位網址，使用：git remote set-url

```git
  git remote set-url origin https://github.com/USERNAME/OTHERREPOSITORY.git
```

3.再次確認Git遠端伺服器網址

```git
  git remote -v
  origin  https://github.com/USERNAME/OTHERREPOSITORY.git (fetch)
  origin  https://github.com/USERNAME/OTHERREPOSITORY.git (push)
```

如果是使用SSH的存取網址，指令一樣是使用git remote set-url，再接上新的SSH URL就可以更換，指令如下：

```git
  git remote set-url origin git@github.com:USERNAME/OTHERREPOSITORY.git
```

不管是要HTTP/HTTPS跟SSH，二種存取網址都是可以直接做更換，然後下次git push/ git fetch 就會到新設定的網址去了唷。

## Git更換遠端tag名稱

步驟如下

```git
  git tag new old
  git tag -d old
  git push origin :refs/tags/old
  git push --tags
```

確認指令

```git
git pull --prune --tags
```

## Git刪除遠端Tag

在Git v1.7.0 之後，可以使用這種語法刪除遠端標籤：

```git
git push origin --delete tag 標籤名
```

## Git多個remote

新增多個遠端倉庫

```git
git remote add 遠端名稱 新的遠端倉庫URL
```

一條指令同時推送到2個遠端地方

```git
git remote set-url --add origin 新的遠端倉庫URL
```
