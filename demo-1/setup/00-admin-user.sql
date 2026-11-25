-- Langkah admin 1: buat user latihan OPS_LAB (pemilik tabel) di XEPDB1
-- Jalankan SEKALI sebagai SYSDBA di dalam container:
--   docker cp setup/00-admin-user.sql oracle-xe:/tmp/00-admin-user.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/00-admin-user.sql
-- Hanya untuk database latihan di laptop. Di database kantor, pekerjaan ini milik DBA.
-- Aman diulang: user dibuat kalau belum ada; kalau sudah ada, hanya password-nya yang diganti.
SET VERIFY OFF FEEDBACK ON
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = XEPDB1;

ACCEPT lab_pwd CHAR PROMPT 'Password baru untuk OPS_LAB: ' HIDE

DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users WHERE username = 'OPS_LAB';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER ops_lab IDENTIFIED BY "&lab_pwd" DEFAULT TABLESPACE users QUOTA UNLIMITED ON users';
  ELSE
    EXECUTE IMMEDIATE 'ALTER USER ops_lab IDENTIFIED BY "&lab_pwd"';
  END IF;
END;
/

-- Hak eksplisit (XE 21c tidak punya DB_DEVELOPER_ROLE)
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO ops_lab;

COLUMN username FORMAT A12
COLUMN account_status FORMAT A16
COLUMN default_tablespace FORMAT A18
SELECT username, account_status, default_tablespace FROM dba_users WHERE username = 'OPS_LAB';
PROMPT Langkah admin 1 selesai.
EXIT
