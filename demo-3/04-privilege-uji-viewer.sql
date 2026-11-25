-- Sesi 10 · Demo 3: Uji dari session OPS_VIEWER (role OPS_READONLY). Koneksi OPS_VIEWER @ XEPDB1, Run Statement satu per satu.

-- 3.3.7 Boleh: baca view incident aktif dan tabel service
SELECT status, COUNT(*) AS jumlah FROM ops_lab.v_incident_aktif GROUP BY status ORDER BY status;
SELECT service_code, service_name FROM ops_lab.service ORDER BY service_code;

-- 3.3.8 Ditolak: tabel incident (hanya view yang diberikan)
SELECT COUNT(*) FROM ops_lab.incident;

-- 3.3.9 Ditolak: memanggil procedure
EXEC ops_lab.assign_incident('INC-SIM-0004', 'op.sari');
