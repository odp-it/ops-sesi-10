-- Langkah admin 4: buat user OPS_VIEWER dan OPS_AGENT serta role OPS_READONLY dan OPS_OPERATOR (Demo 3)
-- Jalankan SEKALI sebagai SYSDBA di dalam container:
--   docker cp setup/01-admin-roles.sql oracle-xe:/tmp/01-admin-roles.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/01-admin-roles.sql
-- Hanya untuk database latihan di laptop. Di database kantor, pekerjaan ini milik DBA.
-- Aman diulang: user dan role dibuat kalau belum ada; password user selalu diganti sesuai yang diketik.
SET VERIFY OFF FEEDBACK ON
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = XEPDB1;

ACCEPT viewer_pwd CHAR PROMPT 'Password baru untuk OPS_VIEWER: ' HIDE
ACCEPT agent_pwd CHAR PROMPT 'Password baru untuk OPS_AGENT: ' HIDE

DECLARE
  PROCEDURE ensure_user (p_name IN VARCHAR2, p_pwd IN VARCHAR2) IS
    n NUMBER;
  BEGIN
    SELECT COUNT(*) INTO n FROM dba_users WHERE username = p_name;
    IF n = 0 THEN
      EXECUTE IMMEDIATE 'CREATE USER ' || p_name || ' IDENTIFIED BY "' || p_pwd || '"';
    ELSE
      EXECUTE IMMEDIATE 'ALTER USER ' || p_name || ' IDENTIFIED BY "' || p_pwd || '"';
    END IF;
  END;
  PROCEDURE ensure_role (p_name IN VARCHAR2) IS
    n NUMBER;
  BEGIN
    SELECT COUNT(*) INTO n FROM dba_roles WHERE role = p_name;
    IF n = 0 THEN
      EXECUTE IMMEDIATE 'CREATE ROLE ' || p_name;
    END IF;
  END;
BEGIN
  ensure_user('OPS_VIEWER', '&viewer_pwd');
  ensure_user('OPS_AGENT', '&agent_pwd');
  ensure_role('OPS_READONLY');
  ensure_role('OPS_OPERATOR');
END;
/

-- Role membawa hak login; user belum punya hak apa pun sampai diberi role
GRANT CREATE SESSION TO ops_readonly;
GRANT CREATE SESSION TO ops_operator;
GRANT ops_readonly TO ops_viewer;
GRANT ops_operator TO ops_agent;

COLUMN username FORMAT A12
COLUMN account_status FORMAT A16
COLUMN granted_role FORMAT A14
SELECT username, account_status FROM dba_users WHERE username IN ('OPS_VIEWER', 'OPS_AGENT') ORDER BY username;
SELECT grantee, granted_role FROM dba_role_privs WHERE grantee IN ('OPS_VIEWER', 'OPS_AGENT') ORDER BY grantee;
PROMPT Langkah admin 4 selesai.
EXIT
