# ansible 使用

有 2 種安裝方法 如下面所示

``` txt
1. pip install ansible & pip install ansible-lint

2. sudo apt-get install ansible (Ubuntu)

3. sudo dnf install -y ansible
```

安裝完畢後 可以開始建立要管理的機器清單

```bash
mkdir ~/ansible

cd ~/ansible

vim hosts
```

hosts 內容

```ini
[servers]
192.168.1.101
192.168.1.102
192.168.1.201
```

## 先設定 SSH 免密碼登入 

1.1 產生 SSH 金鑰（如果還沒有）

```bash
ssh-keygen
```

一路按 Enter，不要輸入密碼。

這會產生：
公鑰：~/.ssh/id_rsa.pub
私鑰：~/.ssh/id_rsa

1.2 把公鑰推送到三台主機上

```bash
ssh-copy-id your_user_name@192.168.1.101
ssh-copy-id your_user_name@192.168.1.102
ssh-copy-id your_user_name@192.168.1.103
```

每次都會問一次密碼，這是最後一次手動輸入密碼了！
完成後，以後 SSH 登入就直接進去，不用密碼了！

```bash
ssh your_user_name@192.168.1.101
```

如果直接進去沒問密碼就成功了。


## 建立任務

```bash
vim upload.yml

- name: Upload file to 3 servers
  hosts: servers
  become: false  # 不需要 sudo 的話
  tasks:
    - name: Upload file
      copy:
        src: /home/mike/testfile.txt
        dest: ~/testfile.txt
```

## 執行

```bash
ansible-playbook -i ansible/hosts ansible/upload.yml -u mike
```

## 一個完整專案架構

Playbook 分拆、模組化、可獨立執行設計

方法一：用 import_playbook ➔ 呼叫別的 yml Playbook
這種是 在大任務裡面引用其他 Playbook，而且這些小 Playbook 自己也可以單獨跑。

方法二：用 include_tasks ➔ 呼叫小段任務
如果只是想要在一個 Play 裡面插入幾個小段任務，而不是整個 Playbook，則用 include_tasks。

方式 | 用途 | 可單獨執行？
import_playbook | 引入另一個完整 Playbook | ✅可以獨立跑
include_tasks | 引入一段 tasks | ❌不能獨立跑
