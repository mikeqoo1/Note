#!/bin/bash
#
# setup-db-audit.sh — 在 DB 容器中啟用 audit log
# 支援 MariaDB (server_audit), PostgreSQL (pgaudit), MSSQL (Server Audit)
#
# 執行方式：
#   sudo bash setup-db-audit.sh
#

set -euo pipefail

echo "========================================="
echo " 資料庫 Audit Log 設定"
echo "========================================="
echo ""
echo "請選擇要設定的資料庫類型："
echo "  1) MariaDB  — 啟用 server_audit plugin"
echo "  2) PostgreSQL — 啟用 pgaudit extension"
echo "  3) MSSQL    — 建立 Server Audit"
echo "  d) Demo 環境一鍵設定（全部）"
echo ""
read -rp "選擇 [1/2/3/d]: " CHOICE

case "${CHOICE}" in
1)
    read -rp "MariaDB 容器名稱 [demo-mariadb]: " CONTAINER
    CONTAINER="${CONTAINER:-demo-mariadb}"
    read -rp "root 密碼: " ROOT_PASS

    echo "啟用 server_audit plugin..."
    sudo docker exec ${CONTAINER} mariadb -uroot -p"${ROOT_PASS}" -e "
    INSTALL SONAME 'server_audit';
    SET GLOBAL server_audit_logging = ON;
    SET GLOBAL server_audit_events = 'CONNECT,QUERY_DDL,QUERY_DML,QUERY_DCL';
    SET GLOBAL server_audit_output_type = 'SYSLOG';
    "
    echo "✅ MariaDB server_audit 已啟用"
    echo "   audit log 會輸出到容器 stdout (docker logs)"
    ;;

2)
    read -rp "PostgreSQL 容器名稱 [demo-postgres]: " CONTAINER
    CONTAINER="${CONTAINER:-demo-postgres}"
    read -rp "postgres 密碼: " PG_PASS

    echo "啟用 pgaudit..."
    sudo docker exec ${CONTAINER} psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pgaudit;"
    sudo docker exec ${CONTAINER} psql -U postgres -c "ALTER SYSTEM SET pgaudit.log = 'ddl, role, write';"
    sudo docker exec ${CONTAINER} psql -U postgres -c "ALTER SYSTEM SET pgaudit.log_catalog = 'off';"
    sudo docker exec ${CONTAINER} psql -U postgres -c "SELECT pg_reload_conf();"

    echo "✅ PostgreSQL pgaudit 已啟用"
    echo "   audit log 會輸出到容器 stdout (docker logs)"
    echo "   ⚠️  如果 pgaudit extension 不存在，需要用有 pgaudit 的 image"
    echo "      例: postgres:16 (已內建) 或 percona/percona-postgresql"
    ;;

3)
    read -rp "MSSQL 容器名稱 [demo-mssql]: " CONTAINER
    CONTAINER="${CONTAINER:-demo-mssql}"
    read -rp "SA 密碼: " SA_PASS

    echo "建立 MSSQL Server Audit..."
    sudo docker exec ${CONTAINER} /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "${SA_PASS}" -C -Q "
    -- 建立 audit 目錄
    EXEC xp_create_subdir '/var/opt/mssql/audit';

    -- 建立 Server Audit
    IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'PMMServerAudit')
    BEGIN
        CREATE SERVER AUDIT PMMServerAudit
        TO FILE (FILEPATH = '/var/opt/mssql/audit/', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 5)
        WITH (ON_FAILURE = CONTINUE);
    END;

    -- 啟用 Server Audit
    ALTER SERVER AUDIT PMMServerAudit WITH (STATE = ON);

    -- 建立 Audit Specification (伺服器層級)
    IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'PMMServerAuditSpec')
    BEGIN
        CREATE SERVER AUDIT SPECIFICATION PMMServerAuditSpec
        FOR SERVER AUDIT PMMServerAudit
        ADD (FAILED_LOGIN_GROUP),
        ADD (SUCCESSFUL_LOGIN_GROUP),
        ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
        ADD (DATABASE_CHANGE_GROUP),
        ADD (SCHEMA_OBJECT_CHANGE_GROUP)
        WITH (STATE = ON);
    END;
    "

    echo "✅ MSSQL Server Audit 已建立"
    echo "   Audit 檔案位於: /var/opt/mssql/audit/"
    echo "   查詢 audit: SELECT * FROM sys.fn_get_audit_file('/var/opt/mssql/audit/*.sqlaudit', DEFAULT, DEFAULT)"
    ;;

d)
    echo "=== Demo 環境 Audit 設定 ==="
    echo ""

    # MariaDB
    if sudo docker ps --format '{{.Names}}' | grep -q "demo-mariadb"; then
        echo "[MariaDB] 啟用 server_audit..."
        sudo docker exec demo-mariadb mariadb -uroot -pRootPass123 -e "
        INSTALL SONAME 'server_audit';
        SET GLOBAL server_audit_logging = ON;
        SET GLOBAL server_audit_events = 'CONNECT,QUERY_DDL,QUERY_DML,QUERY_DCL';
        SET GLOBAL server_audit_output_type = 'SYSLOG';
        " 2>/dev/null && echo "  ✅ MariaDB OK" || echo "  ⚠️ MariaDB 失敗（plugin 可能不存在）"
    else
        echo "[MariaDB] demo-mariadb 容器不存在，跳過"
    fi

    # PostgreSQL
    if sudo docker ps --format '{{.Names}}' | grep -q "demo-postgres"; then
        echo "[PostgreSQL] 啟用 pgaudit..."
        sudo docker exec demo-postgres psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pgaudit;" 2>/dev/null
        sudo docker exec demo-postgres psql -U postgres -c "ALTER SYSTEM SET pgaudit.log = 'ddl, role, write';" 2>/dev/null
        sudo docker exec demo-postgres psql -U postgres -c "SELECT pg_reload_conf();" 2>/dev/null \
            && echo "  ✅ PostgreSQL OK" || echo "  ⚠️ PostgreSQL 失敗（pgaudit 可能未安裝）"
    else
        echo "[PostgreSQL] demo-postgres 容器不存在，跳過"
    fi

    # MSSQL
    if sudo docker ps --format '{{.Names}}' | grep -q "demo-mssql"; then
        echo "[MSSQL] 建立 Server Audit..."
        sudo docker exec demo-mssql /opt/mssql-tools18/bin/sqlcmd \
            -S localhost -U sa -P "YourStrong!Passw0rd" -C -Q "
        EXEC xp_create_subdir '/var/opt/mssql/audit';
        IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'PMMServerAudit')
            CREATE SERVER AUDIT PMMServerAudit TO FILE (FILEPATH = '/var/opt/mssql/audit/', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 5) WITH (ON_FAILURE = CONTINUE);
        ALTER SERVER AUDIT PMMServerAudit WITH (STATE = ON);
        IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'PMMServerAuditSpec')
        BEGIN
            CREATE SERVER AUDIT SPECIFICATION PMMServerAuditSpec FOR SERVER AUDIT PMMServerAudit
            ADD (FAILED_LOGIN_GROUP), ADD (SUCCESSFUL_LOGIN_GROUP), ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
            ADD (DATABASE_CHANGE_GROUP), ADD (SCHEMA_OBJECT_CHANGE_GROUP) WITH (STATE = ON);
        END;
        " 2>/dev/null && echo "  ✅ MSSQL OK" || echo "  ⚠️ MSSQL 失敗"
    else
        echo "[MSSQL] demo-mssql 容器不存在，跳過"
    fi

    echo ""
    echo "Demo 環境 audit 設定完成"
    ;;

*)
    echo "無效選擇"
    exit 1
    ;;
esac

echo ""
echo "下一步：部署 Promtail 收集 audit log"
echo "  sudo bash deploy-promtail.sh http://PMM_SERVER_IP:3100"
