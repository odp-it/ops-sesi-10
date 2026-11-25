-- Sesi 10 · Demo 1 (1.1–1.5): Transaksi, COMMIT, ROLLBACK, SAVEPOINT
-- Koneksi OPS_LAB @ XEPDB1, Auto Commit mati. Jalankan SATU PERINTAH sekali jalan dengan Run Statement
-- (Ctrl+Enter / Cmd+Enter), urut dari atas, dan baca hasilnya sebelum lanjut.

-- 1.1 Cek data: 4 status, jumlah per status
SELECT status, COUNT(*) AS jumlah FROM incident GROUP BY status ORDER BY status;

-- 1.2 Ambil incident INC-SIM-0004 jadi satu transaksi: ubah status + catat log
SELECT incident_no, priority, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0004';

UPDATE incident
SET status = 'IN_PROGRESS', assigned_to = 'op.andi', updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0004';

INSERT INTO incident_log (log_id, incident_id, old_status, new_status, changed_by, note)
VALUES (seq_incident_log.NEXTVAL, (SELECT incident_id FROM incident WHERE incident_no = 'INC-SIM-0004'),
        'OPEN', 'IN_PROGRESS', 'op.andi', 'Diambil operator');

-- Dari session ini perubahan sudah terlihat, tetapi belum permanen
SELECT incident_no, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0004';
SELECT COUNT(*) AS jumlah_log FROM incident_log;

-- 1.2b Batalkan semuanya
ROLLBACK;

SELECT incident_no, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0004';
SELECT COUNT(*) AS jumlah_log FROM incident_log;

-- 1.2c Ulangi kedua perintah (UPDATE dan INSERT), lalu simpan permanen
UPDATE incident
SET status = 'IN_PROGRESS', assigned_to = 'op.andi', updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0004';

INSERT INTO incident_log (log_id, incident_id, old_status, new_status, changed_by, note)
VALUES (seq_incident_log.NEXTVAL, (SELECT incident_id FROM incident WHERE incident_no = 'INC-SIM-0004'),
        'OPEN', 'IN_PROGRESS', 'op.andi', 'Diambil operator');

COMMIT;

SELECT log_id, old_status, new_status, changed_by, note FROM incident_log;

-- 1.3 Error di tengah transaksi: statement yang gagal dibatalkan, perubahan sebelumnya TIDAK
UPDATE incident
SET status = 'RESOLVED', closed_at = SYSTIMESTAMP, updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0003';

-- Salah ketik status log: 'SELESAI' tidak ada di daftar
INSERT INTO incident_log (log_id, incident_id, old_status, new_status, changed_by, note)
VALUES (seq_incident_log.NEXTVAL, (SELECT incident_id FROM incident WHERE incident_no = 'INC-SIM-0003'),
        'OPEN', 'SELESAI', 'op.sari', 'Salah ketik');

-- UPDATE pertama masih menggantung di transaksi ini
SELECT incident_no, status FROM incident WHERE incident_no = 'INC-SIM-0003';

ROLLBACK;

SELECT incident_no, status FROM incident WHERE incident_no = 'INC-SIM-0003';

-- 1.4 SAVEPOINT: batalkan sebagian saja
UPDATE incident SET priority = 'P2' WHERE incident_no = 'INC-SIM-0001';
SAVEPOINT setelah_0001;
UPDATE incident SET priority = 'P1' WHERE incident_no = 'INC-SIM-0002';
ROLLBACK TO SAVEPOINT setelah_0001;

SELECT incident_no, priority FROM incident WHERE incident_no IN ('INC-SIM-0001', 'INC-SIM-0002') ORDER BY incident_no;

ROLLBACK;

SELECT incident_no, priority FROM incident WHERE incident_no IN ('INC-SIM-0001', 'INC-SIM-0002') ORDER BY incident_no;

-- 1.5 DDL di tengah transaksi = COMMIT otomatis
UPDATE incident SET summary = summary || ' (dicek)' WHERE incident_no = 'INC-SIM-0001';
CREATE TABLE catatan_sementara (id NUMBER);
ROLLBACK;

-- ROLLBACK tidak berlaku: UPDATE sudah ikut tersimpan oleh CREATE TABLE
SELECT summary FROM incident WHERE incident_no = 'INC-SIM-0001';

-- 1.5b Kembalikan seperti semula
UPDATE incident SET summary = 'Halaman login portal lambat' WHERE incident_no = 'INC-SIM-0001';
COMMIT;
DROP TABLE catatan_sementara PURGE;
