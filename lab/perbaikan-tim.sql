-- Sesi 10 · Lab: perbaikan insiden milik tim. Salin file ini menjadi perbaikan-<nama-tim>.sql.
-- Koneksi OPS_LAB @ XEPDB1. Lengkapi setiap TODO. File harus bisa dijalankan utuh (F5) setelah 00-insiden.sql.
-- Aturan lengkap, kode error, dan rubrik: README bagian Lab.

-- ===== A. Pemulihan data (satu transaksi: SAVEPOINT, cek, lalu COMMIT) =====
-- Cari dulu tiket yang melanggar aturan data (README Lab, tabel aturan).
SELECT incident_no, status, assigned_to, closed_at, updated_at
FROM incident
WHERE incident_no NOT LIKE 'INC-SIM-B%'
  AND (   (status IN ('RESOLVED', 'CLOSED') AND closed_at IS NULL)
       OR (status = 'OPEN' AND (assigned_to IS NOT NULL OR closed_at IS NOT NULL))
       OR (status = 'IN_PROGRESS' AND assigned_to IS NULL))
ORDER BY incident_no;

-- Lost update tidak terlihat dari aturan di atas: telusuri riwayat tiket yang dilaporkan tertimpa
SELECT i.incident_no, i.assigned_to, l.changed_at, l.changed_by, l.old_status, l.new_status, l.note
FROM incident_log l JOIN incident i ON i.incident_id = l.incident_id
WHERE i.incident_no = 'INC-SIM-0022'
ORDER BY l.changed_at;

SAVEPOINT sebelum_perbaikan;
-- TODO A1: isi closed_at tiket RESOLVED/CLOSED yang kosong dari updated_at
-- TODO A2: rapikan tiket OPEN yang masih punya operator
-- TODO A3: kembalikan tiket IN_PROGRESS tanpa operator ke antrean
-- TODO A4: kembalikan tiket yang tertimpa ke pemegang sah
-- Jalankan lagi query pencari di atas (harus 0 baris), baru COMMIT. Salah? ROLLBACK TO SAVEPOINT sebelum_perbaikan.
-- TODO: COMMIT

-- ===== B. Procedure serah terima: handover_incident =====
-- TODO B: CREATE OR REPLACE PROCEDURE handover_incident (p_incident_no IN VARCHAR2,
--            p_from_operator IN VARCHAR2, p_to_operator IN VARCHAR2) ... /
--         Kunci baris, cek aturan, UPDATE, catat ke incident_log. Tanpa COMMIT dan ROLLBACK.

-- ===== C. Penjaga data =====
-- TODO C1: CREATE OR REPLACE FUNCTION active_incident_count (p_service_code IN VARCHAR2) RETURN NUMBER ... /
-- TODO C2: CREATE OR REPLACE TRIGGER trg_incident_guard BEFORE UPDATE ON incident ... /
--          Status CLOSED tidak boleh diubah lagi (RAISE_APPLICATION_ERROR). Kolom lain boleh.

-- ===== D. Hak akses (pemilik tabel). User dan role auditor dibuat admin: admin-auditor-tim.sql =====
SELECT grantee, table_name, privilege FROM user_tab_privs_made WHERE grantee <> 'PUBLIC' ORDER BY grantee, table_name, privilege;
-- TODO D1: cabut hak yang berlebih (jangan REVOKE ALL: hak yang sah harus tetap ada)
-- TODO D2: beri OPS_OPERATOR hak menjalankan handover_incident
-- TODO D3: view v_incident_audit (incident_no, status, priority, assigned_to, updated_at), tanpa summary
-- TODO D4: beri role OPS_AUDIT hak baca incident_log dan v_incident_audit saja

-- ===== E. Laporan lambat (butuh data bulk: ../demo-4/05-bulk-incident.sql, JUMLAH_INCIDENT 200030) =====
-- Query lama dari dashboard. Jalankan EXPLAIN PLAN-nya dulu sebagai bukti "sebelum".
EXPLAIN PLAN SET STATEMENT_ID = 'lab-sebelum' FOR
SELECT incident_no, priority, assigned_to, opened_at
FROM incident
WHERE service_id = 3
  AND UPPER(status) = 'IN_PROGRESS'
  AND TRUNC(opened_at, 'MM') = DATE '2026-09-01'
ORDER BY opened_at;
SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'lab-sebelum', 'BASIC +COST +ROWS +PREDICATE'));

-- TODO E1: CREATE OR REPLACE VIEW v_laporan_antrean AS  (hasil sama persis, tanpa ORDER BY di view)
-- TODO E2: CREATE INDEX idx_lab_... ON incident (...);  nama index wajib berawalan idx_lab_
-- TODO E3: EXPLAIN PLAN untuk SELECT * FROM v_laporan_antrean, catat operation dan cost sesudahnya
