-- Sesi 10 · Demo 3: Uji dari session OPS_AGENT (role OPS_OPERATOR). Koneksi OPS_AGENT @ XEPDB1, Run Statement satu per satu.
-- Nama objek milik OPS_LAB harus diberi awalan ops_lab. (user lain tidak punya synonym).

-- 3.3.1 Boleh: baca incident
SELECT status, COUNT(*) AS jumlah FROM ops_lab.incident GROUP BY status ORDER BY status;

-- 3.3.2 Boleh: ambil incident lewat procedure
EXEC ops_lab.assign_incident('INC-SIM-0003', 'op.sari');
SELECT incident_no, status, assigned_to FROM ops_lab.incident WHERE incident_no = 'INC-SIM-0003';

-- 3.3.3 Ditolak: UPDATE langsung (hanya punya SELECT)
UPDATE ops_lab.incident SET status = 'CLOSED' WHERE incident_no = 'INC-SIM-0004';

-- 3.3.4 Ditolak: tabel yang tidak diberikan sama sekali (dari sisi OPS_AGENT, tabel itu seolah tidak ada)
SELECT COUNT(*) FROM ops_lab.incident_log;

-- 3.3.5 Ditolak: membuat objek
CREATE TABLE catatan_agent (id NUMBER);

-- 3.3.6 Dari mana izin ini datang: role yang aktif, lalu isi role itu
SELECT * FROM session_roles;
SELECT role, table_name, privilege FROM role_tab_privs ORDER BY table_name, privilege;

-- 3.4.3 (setelah OPS_LAB menjalankan 3.4.1) Eskalasi sekarang ditolak. Sebelum 3.4.1, perintah ini berhasil.
EXEC ops_lab.escalate_incident('INC-SIM-0003', 'op.sari');
