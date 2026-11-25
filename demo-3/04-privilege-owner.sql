-- Sesi 10 · Demo 3: Pemilik tabel memberi izin (OPS_LAB). Koneksi OPS_LAB @ XEPDB1, Run Script (F5).
-- Prasyarat: setup/01-admin-roles.sql sudah dijalankan (user dan role ada).

-- 3.2.1 View yang membatasi data: hanya incident aktif, tanpa kolom assigned_to
CREATE OR REPLACE VIEW v_incident_aktif AS
SELECT incident_no, service_id, category, priority, status, summary, opened_at
FROM incident
WHERE status IN ('OPEN', 'IN_PROGRESS');

-- 3.2.2 OPS_READONLY: hanya membaca. Tabel incident TIDAK diberikan, hanya view-nya
GRANT SELECT ON asset TO ops_readonly;
GRANT SELECT ON service TO ops_readonly;
GRANT SELECT ON v_incident_aktif TO ops_readonly;

-- 3.2.3 OPS_OPERATOR: membaca, dan mengubah incident hanya lewat procedure (EXECUTE), bukan UPDATE langsung
GRANT SELECT ON asset TO ops_operator;
GRANT SELECT ON service TO ops_operator;
GRANT SELECT ON incident TO ops_operator;
GRANT EXECUTE ON assign_incident TO ops_operator;
GRANT EXECUTE ON escalate_incident TO ops_operator;

-- 3.2.4 Cek izin yang sudah diberikan
SELECT grantee, table_name, privilege FROM user_tab_privs_made WHERE grantee <> 'PUBLIC' ORDER BY grantee, table_name, privilege;
