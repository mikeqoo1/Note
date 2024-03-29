# 其他項目

## Node.js

nvm install
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

nvm install --lts

```

## CentOS安裝Java
```
sudo yum install java-1.8.0-openjdk.x86_64
sudo yum install java-1.8.0-openjdk-devel.x86_64
sudo yum install java-1.8.0-openjdk-headless.x86_64
sudo yum install javapackages-tools.noarch
sudo yum install python-javapackages.noarch
sudo yum install tzdata-java.noarch
```

## CentOS安裝Golang
```
sudo yum install golang
```

## Clang-Format格式化教學

在vscode 上使用 C/C++ 的排版功能
```
Clang-Format可用格式化多種不同語言的code, 排版格式主要有：LLVM, Google, Chromium, Mozilla, WebKit

選項設定
打開設定（ctrl + ,）搜索format 

勾選format on save 自動保存


C_Cpp: Clang_format_style 決定格式化形式, 如果是file, 則是使用在workspace中的.clang-format


C_Cpp: Clang_format_fallback Style, 如果上面的選項是file, 但是沒有.clang-format文件

處理方法
終端機中输入

clang-format -style=5種格式選一個 -dump-config > .clang-format
```

## MariadbCpp Lib 安裝

cmake > 3.1.0 && gcc 要支援 C++11

```
sudo yum -y install git cmake make gcc openssl-devel
git clone https://github.com/MariaDB-Corporation/mariadb-connector-cpp.git
mkdir build && cd build
cmake ../mariadb-connector-cpp/ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off -DCMAKE_INSTALL_PREFIX=/usr/local -DWITH_SSL=OPENSSL
cmake --build . --config RelWithDebInfo
sudo make install
```

cmake 升級

```
wget https://cmake.org/files/v3.17/cmake-3.17.3.tar.gz
tar -zxvf cmake-3.17.3.tar.gz
cd cmake-3.17.3
sudo ./bootstrap --prefix=/usr/local
sudo make
sudo make install
vi ~/.bash_profile
PATH=/usr/local/bin:$PATH:$HOME/bin

```

## mycli安裝
```bash
sudo yum install python3-devel
sudo pip3 install mycli
```

## Docker 更新

先把遠端的images pull下來, 開啟容器, 進入修改後, commit起來 在推上去

sudo docker run $映像檔 --name $容器名稱 -i -t /bin/bash

sudo docker run 106061/rocky9cicd -i -t /bin/bash

sudo docker commit -m "訊息內容" $容器名稱 $映像檔

sudo docker push $映像檔
