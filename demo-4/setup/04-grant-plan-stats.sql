-- Langkah admin 5: izin membaca statistik eksekusi (DBMS_XPLAN.DISPLAY_CURSOR) untuk OPS_LAB (Demo 4, langkah 4.1)
-- Jalankan SEKALI sebagai SYSDBA di dalam container:
--   docker cp setup/04-grant-plan-stats.sql oracle-xe:/tmp/04-grant-plan-stats.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/04-grant-plan-stats.sql
-- Hanya untuk database latihan di laptop. Di database kantor, izin seperti ini diatur DBA.
SET FEEDBACK ON
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT SELECT ON sys.v_$session TO ops_lab;
GRANT SELECT ON sys.v_$sql TO ops_lab;
GRANT SELECT ON sys.v_$sql_plan TO ops_lab;
GRANT SELECT ON sys.v_$sql_plan_statistics_all TO ops_lab;

PROMPT Izin statistik plan untuk OPS_LAB selesai.
EXIT
