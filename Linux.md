### 新增使用者
sudo useradd 帳號名稱

### 設定密碼
sudo passwd 帳號名稱

### 指定群組
指定主要群組: sudo useradd -g 主要群組名稱 帳號名稱

加入其他群組: sudo useradd -g 主要群組名稱 -G 次要群組1,次要群組2 帳號名稱

### 修改主要群組
usermod -g 主要群組 帳號名稱

### 增加次要群組
usermod -a -G 次要群組 帳號名稱