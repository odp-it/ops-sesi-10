-- Sesi 10 · Demo 4: Execution plan sebelum dan sesudah index
-- Jalankan per perintah dengan Run Statement, urut dari atas. Hasil DBMS_XPLAN tampil sebagai tabel di Query Result.
-- Query yang dioptimasi: daftar incident P1 yang masih OPEN sejak 1 Juni 2026, urut waktu buka.
-- 4.5 dan 4.8 butuh izin dari setup/04-grant-plan-stats.sql (README langkah 4.1).

-- 4.3 Pastikan index latihan belum ada (expected: hanya index PK dan UNIQUE bawaan constraint)
SELECT index_name, column_name, column_position
FROM user_ind_columns WHERE table_name = 'INCIDENT' ORDER BY index_name, column_position;

-- 4.4 Plan SEBELUM index: perkiraan optimizer (query belum dijalankan)
EXPLAIN PLAN SET STATEMENT_ID = 'sebelum' FOR
SELECT incident_no, priority, opened_at, summary
FROM incident
WHERE status = 'OPEN'
  AND priority = 'P1'
  AND opened_at >= TIMESTAMP '2026-06-01 00:00:00'
ORDER BY opened_at;

SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'sebelum', 'TYPICAL'));

-- 4.5 Jalankan query SEBELUM index sambil merekam statistik, lalu lihat blok data (Buffers) yang dibaca
SELECT /*+ GATHER_PLAN_STATISTICS */ /* incident-sebelum */ incident_no, priority, opened_at, summary
FROM incident
WHERE status = 'OPEN'
  AND priority = 'P1'
  AND opened_at >= TIMESTAMP '2026-06-01 00:00:00'
ORDER BY opened_at;

SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
  (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /*+ GATHER_PLAN_STATISTICS */ /* incident-sebelum */%'
   ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY),
  (SELECT child_number FROM v$sql WHERE sql_text LIKE 'SELECT /*+ GATHER_PLAN_STATISTICS */ /* incident-sebelum */%'
   ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY),
  'ALLSTATS LAST'));

-- 4.6 Buat index composite: kolom filter "=" dulu, kolom rentang sesudahnya
CREATE INDEX idx_incident_status_prio_opened ON incident (status, priority, opened_at);

-- 4.7 Plan SESUDAH index (query sama persis)
EXPLAIN PLAN SET STATEMENT_ID = 'sesudah' FOR
SELECT incident_no, priority, opened_at, summary
FROM incident
WHERE status = 'OPEN'
  AND priority = 'P1'
  AND opened_at >= TIMESTAMP '2026-06-01 00:00:00'
ORDER BY opened_at;

SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'sesudah', 'TYPICAL'));

-- 4.8 Jalankan query SESUDAH index, lihat Buffers
SELECT /*+ GATHER_PLAN_STATISTICS */ /* incident-sesudah */ incident_no, priority, opened_at, summary
FROM incident
WHERE status = 'OPEN'
  AND priority = 'P1'
  AND opened_at >= TIMESTAMP '2026-06-01 00:00:00'
ORDER BY opened_at;

SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
  (SELECT sql_id FROM v$sql WHERE sql_text LIKE 'SELECT /*+ GATHER_PLAN_STATISTICS */ /* incident-sesudah */%'
   ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY),
  (SELECT child_number FROM v$sql WHERE sql_text LIKE 'SELECT /*+ GATHER_PLAN_STATISTICS */ /* incident-sesudah */%'
   ORDER BY last_active_time DESC FETCH FIRST 1 ROW ONLY),
  'ALLSTATS LAST'));

-- 4.9 Index tidak terpakai: filter hanya di kolom terakhir index (opened_at), kolom pertama tidak disebut
EXPLAIN PLAN SET STATEMENT_ID = 'kolom-ketiga' FOR
SELECT incident_no, opened_at FROM incident
WHERE opened_at >= TIMESTAMP '2026-10-20 00:00:00';

SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'kolom-ketiga', 'BASIC +COST +ROWS +PREDICATE'));

-- 4.10 Index tidak terpakai: fungsi membungkus kolom index
EXPLAIN PLAN SET STATEMENT_ID = 'fungsi' FOR
SELECT incident_no, opened_at FROM incident
WHERE UPPER(status) = 'OPEN';

SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'fungsi', 'BASIC +COST +ROWS +PREDICATE'));

-- 4.11 Index tidak selalu menang: status CLOSED mewakili ±90% baris, membaca lewat index malah lebih mahal
EXPLAIN PLAN SET STATEMENT_ID = 'closed' FOR
SELECT incident_no, opened_at FROM incident
WHERE status = 'CLOSED';

SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'closed', 'BASIC +COST +ROWS +PREDICATE'));
