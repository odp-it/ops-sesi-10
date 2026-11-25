-- Langkah admin 3: matikan session yang menahan lock (1.12.4). Hanya untuk database latihan.
--   docker cp setup/03-admin-matikan-session.sql oracle-xe:/tmp/03-admin-matikan-session.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/03-admin-matikan-session.sql
-- Isi dengan SID dan SERIAL# session penahan dari 02-admin-lihat-lock.sql, format: 320,42508
-- Transaksi session itu otomatis di-ROLLBACK, lalu session yang menunggu berjalan lagi.
SET VERIFY OFF FEEDBACK ON
ALTER SESSION SET CONTAINER = XEPDB1;
ACCEPT sid_serial CHAR PROMPT 'SID,SERIAL# session yang dimatikan (contoh 320,42508): '
ALTER SYSTEM KILL SESSION '&sid_serial';
EXIT
