## 14 → 15 正確做法

### 1. 先停 GitLab

```bash
sudo docker compose stop gitlab
```

先不要讓 GitLab 在 dump/restore 過程寫資料。

---

### 2. 在 PG14 再做一份最新 SQL 備份

你雖然之前有一份，但現在既然確認 PG14 是正確資料，建議重做一次。

```bash
mkdir -p /opt/postgresql-upgrade-backup
sudo docker exec -t mike-postgresql-1 pg_dumpall -U postgres > /opt/postgresql-upgrade-backup/gitlab_pg14_all.sql
```

---

### 3. 改 compose 成 PG15

把：

```yaml
image: sameersbn/postgresql:14-20230628
```

改成：

```yaml
image: sameersbn/postgresql:15-20230628
```

volume 先維持不變：

```yaml
- /opt/postgresql:/var/lib/postgresql:Z
```

---

### 4. 只啟 PostgreSQL 15

```bash
sudo docker compose up -d postgresql
```

確認它現在跑的是 15：

```bash
sudo docker exec -it mike-postgresql-1 psql -U postgres -d gitlabhq_production -c "select version(); select current_setting('data_directory');"
```

你要看到：

* PostgreSQL 15.x
* `/var/lib/postgresql/15/main`

---

### 5. 先把空的 DB 清掉

因為 PG15 那邊之前已經有半套資料，先清乾淨最安全。

先進 postgres：

```bash
sudo docker exec -it mike-postgresql-1 psql -U postgres
```

然後執行：

```sql
DROP DATABASE IF EXISTS gitlabhq_production;
DROP ROLE IF EXISTS gitlab;
\q
```

---

### 6. 把 PG14 備份匯入 PG15

```bash
cat /opt/postgresql-upgrade-backup/gitlab_pg14_all.sql | sudo docker exec -i mike-postgresql-1 psql -U postgres
```

這一步會重建：

* role
* database
* schema
* data

---

### 7. 驗證 PG15 資料

```bash
sudo docker exec -it mike-postgresql-1 psql -U postgres -d gitlabhq_production -c "
select 'users' as table_name, count(*) from users
union all
select 'projects', count(*) from projects
union all
select 'namespaces', count(*) from namespaces
union all
select 'members', count(*) from members
union all
select 'routes', count(*) from routes;
"
```

你要看到跟 PG14 很接近：

* users 45
* projects 249
* namespaces 323
* members 226
* routes 323

再確認版本：

```bash
sudo docker exec -it mike-postgresql-1 psql -U postgres -d gitlabhq_production -c "select version(); select current_setting('data_directory');"
```

---

### 8. 啟 GitLab

```bash
sudo docker compose up -d gitlab
```

看 log：

```bash
sudo docker logs -f mike-gitlab-1
```

---

### 9. 驗證 GitLab

進 container：

```bash
sudo docker exec -it mike-gitlab-1 bash
cd /home/git/gitlab/bin
./rake db:abort_if_pending_migrations
```

如果沒報錯，就去 Web 驗證：

* 能登入
* 專案數正常
* Admin 頁面正常

---

## 如果 14 → 15 成功，15 → 16 就照抄一次

只是把備份檔名字和 image 換掉。

### 在 PG15 上匯出

```bash
sudo docker compose stop gitlab
sudo docker exec -t mike-postgresql-1 pg_dumpall -U postgres > /opt/postgresql-upgrade-backup/gitlab_pg15_all.sql
```

### 改 compose 成 16

```yaml
image: kkimurak/sameersbn-postgresql:16
```

### 起 PG16

```bash
sudo docker compose up -d postgresql
```

### 清空舊半套 DB

```bash
sudo docker exec -it mike-postgresql-1 psql -U postgres
```

```sql
DROP DATABASE IF EXISTS gitlabhq_production;
DROP ROLE IF EXISTS gitlab;
\q
```

### 匯入 PG15 備份

```bash
cat /opt/postgresql-upgrade-backup/gitlab_pg15_all.sql | sudo docker exec -i mike-postgresql-1 psql -U postgres
```

### 驗證資料量

再跑同一組 count SQL。

### 啟 GitLab

```bash
sudo docker compose up -d gitlab
```

---

## 這次最重要的原則

每一版都守住這個流程：

1. 停 GitLab
2. 匯出 SQL
3. 升 PostgreSQL image
4. 清掉新版本裡半套 DB
5. restore
6. 驗證 count
7. 啟 GitLab



很好，這個坑其實**很經典而且很容易踩第二次**，我幫你整理成一份「可以放專案的標準文件」，你之後直接丟到 repo / AGENTS.md / wiki 都可以用👇

---

# 📘 GitLab PostgreSQL 升級踩坑紀錄（實戰版）

## 🎯 問題背景

在使用 `sameersbn/gitlab` + `sameersbn/postgresql` 升級 PostgreSQL（14 → 15 → 16 → 18）過程中：

* PostgreSQL 升級成功
* GitLab 啟動正常
* **但在升級 GitLab 18.x 時 migration 失敗**

---

## ❗ 錯誤訊息

```text
PG::InsufficientPrivilege: ERROR: permission denied for schema public
```

發生位置：

```text
db:migrate
add_index / schema change
```

---

## 🔥 問題本質（超重要）

👉 **資料有過去，但「權限/owner 沒過去」**

原因：

* 使用 `pg_dump / restore` 或自動升級後
* DB object（table / sequence / function）仍屬於 `postgres`
* GitLab 使用的是 `gitlab` user
* Migration 需要 DDL 權限（CREATE INDEX / ALTER TABLE）
* → 直接爆炸 💥

---

## 🧠 核心觀念（一定要記）

| 項目                  | 正確狀態   |
| ------------------- | ------ |
| database owner      | gitlab |
| schema public owner | gitlab |
| tables owner        | gitlab |
| sequences owner     | gitlab |
| functions owner     | gitlab |

👉 **只改 schema 不夠，一定要改 object owner**

---

## 🛠️ 解法（標準修復流程）

### 1️⃣ 停 GitLab

```bash
docker compose stop gitlab
```

---

### 2️⃣ 進 PostgreSQL

```bash
docker exec -it mike-postgresql-1 psql -U postgres -d gitlabhq_production
```

---

### 3️⃣ 修正 schema + 權限

```sql
ALTER DATABASE gitlabhq_production OWNER TO gitlab;
ALTER SCHEMA public OWNER TO gitlab;

GRANT ALL ON SCHEMA public TO gitlab;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO gitlab;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO gitlab;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO gitlab;
```

---

### 4️⃣ 🔥 最關鍵：修正所有 object owner

```sql
-- tables
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE %I.%I OWNER TO gitlab;', r.schemaname, r.tablename);
  END LOOP;
END$$;

-- sequences
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT sequence_schema, sequence_name
    FROM information_schema.sequences
    WHERE sequence_schema = 'public'
  LOOP
    EXECUTE format('ALTER SEQUENCE %I.%I OWNER TO gitlab;', r.sequence_schema, r.sequence_name);
  END LOOP;
END$$;

-- functions
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
  LOOP
    EXECUTE format('ALTER FUNCTION %I.%I(%s) OWNER TO gitlab;', r.nspname, r.proname, r.args);
  END LOOP;
END$$;
```

---

### 5️⃣ 啟動 GitLab

```bash
docker compose up -d gitlab
docker logs -f mike-gitlab-1
```

---

## ✅ 驗證成功

* migration 正常跑完
* GitLab UI 正常
* DB 有資料
* version 正確（例如 18.2.8）

---

## 🚨 常見誤區

### ❌ 誤區 1：只改 schema owner

👉 不夠，一定會炸

---

### ❌ 誤區 2：用 REASSIGN OWNED

```sql
REASSIGN OWNED BY postgres TO gitlab;
```

👉 會失敗：

```text
cannot reassign ownership ... required by the database system
```

👉 正確做法：**只改 public schema 物件**

---

### ❌ 誤區 3：以為資料 OK 就沒問題

👉 GitLab migration 很吃 DDL 權限

---

## 🧩 升級順序建議（你這次走的是正確的）

```text
PostgreSQL:
14 → 15 → 16 → (18)

GitLab:
17.11 → 18.2 → 18.x latest
```

👉 不要跳版本（會炸）

---

## 💡 最佳實務（避免再踩）

### ✔ 每次 DB restore 後做這一步：

```sql
-- 一次性修復 owner
(上面 DO $$ 那三段)
```

👉 可以做成 script（你可以丟進 DevOps）

---

### ✔ 建議加進你的 DevOps 流程

你可以做：

```bash
fix_gitlab_db_owner.sh
```

👉 未來直接一鍵修復

---

## 🧠 一句話總結

👉 **GitLab 升級失敗 ≠ DB 壞掉**
👉 **99% 是權限/owner 問題**

---

如果你要，我可以幫你把這份再升級成：

* ✅ `README.md`（含架構圖）
* ✅ `AGENTS.md`（讓 AI 自動修）
* ✅ 自動化 script（CI/CD 用）

甚至可以直接變成你公司「升級 SOP 文件」。
