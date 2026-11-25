-- Sesi 10 · Lab: admin membuat akun auditor. Salin menjadi admin-auditor-<nama-tim>.sql, lengkapi TODO, lalu:
--   docker cp admin-auditor-<nama-tim>.sql oracle-xe:/tmp/admin-auditor.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/admin-auditor.sql
-- Password latihan diketik di terminal (tidak masuk file). Hanya untuk database latihan.
SET VERIFY OFF FEEDBACK ON
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = XEPDB1;

ACCEPT auditor_pwd CHAR PROMPT 'Password baru untuk OPS_AUDITOR: ' HIDE

-- TODO 1: CREATE USER ops_auditor dengan password "&auditor_pwd"
-- TODO 2: CREATE ROLE ops_audit
-- TODO 3: beri role itu hak login saja (hak objek diberikan OPS_LAB di perbaikan-<tim>.sql)
-- TODO 4: beri role ops_audit ke ops_auditor

SELECT grantee, granted_role FROM dba_role_privs WHERE grantee = 'OPS_AUDITOR';
EXIT
