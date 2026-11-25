-- Langkah admin 2: lihat session yang saling mengunci (langkah 1.12). Dijalankan sebagai SYSDBA saat session A menahan lock
-- dan session B menunggu (1.7.3). Cara jalan:
--   docker cp setup/02-admin-lihat-lock.sql oracle-xe:/tmp/02-admin-lihat-lock.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/02-admin-lihat-lock.sql
-- Hanya membaca (V$SESSION, V$LOCK). Mematikan session: setup/03-admin-matikan-session.sql (1.12.4).
SET VERIFY OFF FEEDBACK ON LINESIZE 160 PAGESIZE 50
ALTER SESSION SET CONTAINER = XEPDB1;

COLUMN username FORMAT A10
COLUMN status FORMAT A9
COLUMN event FORMAT A32
COLUMN blocking_session HEADING BLOCKER

-- 1. Session OPS_LAB: siapa menunggu siapa
SELECT sid, serial#, username, status, blocking_session, event, seconds_in_wait AS detik
FROM v$session
WHERE username = 'OPS_LAB'
ORDER BY sid;

-- 2. Lock di tabel INCIDENT: BLOCK = 1 artinya memegang lock yang ditunggu session lain
COLUMN type FORMAT A4
SELECT l.sid, l.type, l.lmode, l.request, l.block
FROM v$lock l
JOIN v$session s ON s.sid = l.sid
WHERE s.username = 'OPS_LAB' AND l.type IN ('TX', 'TM')
ORDER BY l.sid, l.type;

-- 3. Perintah yang sedang ditunggu (session B)
COLUMN sql_text FORMAT A70
SELECT s.sid AS menunggu, s.blocking_session AS penahan, q.sql_text
FROM v$session s
JOIN v$sql q ON q.sql_id = s.sql_id
WHERE s.username = 'OPS_LAB' AND s.blocking_session IS NOT NULL;

EXIT
