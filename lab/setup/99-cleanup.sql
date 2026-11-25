-- Hapus semua objek latihan sesi 10 (opsional, setelah selesai). Jalankan sebagai SYSDBA:
--   docker cp setup/99-cleanup.sql oracle-xe:/tmp/99-cleanup.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/99-cleanup.sql
-- Menghapus user OPS_LAB beserta semua tabelnya, OPS_VIEWER, OPS_AGENT, OPS_AUDITOR (Lab), dan ketiga role.
-- Tidak bisa dibatalkan.
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = XEPDB1;
BEGIN
  FOR u IN (SELECT username FROM dba_users WHERE username IN ('OPS_LAB', 'OPS_VIEWER', 'OPS_AGENT', 'OPS_AUDITOR')) LOOP
    FOR s IN (SELECT sid, serial# FROM v$session WHERE username = u.username) LOOP
      EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || s.sid || ',' || s.serial# || ''' IMMEDIATE';
    END LOOP;
    EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
  END LOOP;
  FOR r IN (SELECT role FROM dba_roles WHERE role IN ('OPS_READONLY', 'OPS_OPERATOR', 'OPS_AUDIT')) LOOP
    EXECUTE IMMEDIATE 'DROP ROLE ' || r.role;
  END LOOP;
END;
/
SELECT username FROM dba_users WHERE username LIKE 'OPS%';
EXIT
