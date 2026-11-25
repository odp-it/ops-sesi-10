-- Sesi 10 · Lab: pasang kondisi insiden (data rusak dan hak akses berlebih). Jalankan sebagai OPS_LAB, Run Script (F5).
-- Aman diulang: dipakai juga untuk mengulang Lab dari awal. Objek Lab lama dihapus (handover_incident,
-- active_incident_count, trg_incident_guard, v_laporan_antrean, v_incident_audit, index IDX_LAB...).
-- Prasyarat: tabel dari catch-up atau sesi 7-9, dan role dari ../demo-3/setup/01-admin-roles.sql (Demo 3).
-- Hanya untuk database latihan. Tidak ada tiket yang dihapus; yang diubah hanya 5 tiket dan lognya.
SET DEFINE OFF
SET SERVEROUTPUT ON

DECLARE
  n NUMBER;

  PROCEDURE coba(p_sql VARCHAR2, p_abaikan PLS_INTEGER) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE <> p_abaikan THEN RAISE; END IF;
  END;

  PROCEDURE log_lab(p_no VARCHAR2, p_old VARCHAR2, p_new VARCHAR2, p_by VARCHAR2, p_at TIMESTAMP, p_note VARCHAR2) IS
  BEGIN
    INSERT INTO incident_log (log_id, incident_id, old_status, new_status, changed_by, changed_at, note)
    SELECT seq_incident_log.NEXTVAL, incident_id, p_old, p_new, p_by, p_at, p_note || ' [LAB]'
      FROM incident WHERE incident_no = p_no;
  END;
BEGIN
  -- Hak berlebih pertama sekaligus cek role: kalau role belum ada, skrip berhenti di sini tanpa mengubah apa pun
  BEGIN
    EXECUTE IMMEDIATE 'GRANT SELECT ON incident TO ops_operator';
    EXECUTE IMMEDIATE 'GRANT SELECT ON incident_log TO ops_readonly';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20900,
        'Role OPS_OPERATOR / OPS_READONLY belum ada. Jalankan ../demo-3/setup/01-admin-roles.sql dulu (README Demo 3). ' || SQLERRM);
  END;
  EXECUTE IMMEDIATE 'GRANT UPDATE, DELETE ON incident TO ops_operator';

  -- Bersihkan objek Lab dari percobaan sebelumnya
  coba('DROP TRIGGER trg_incident_guard', -4080);
  coba('DROP PROCEDURE handover_incident', -4043);
  coba('DROP FUNCTION active_incident_count', -4043);
  coba('DROP VIEW v_laporan_antrean', -942);
  coba('DROP VIEW v_incident_audit', -942);
  FOR i IN (SELECT index_name FROM user_indexes WHERE table_name = 'INCIDENT' AND index_name LIKE 'IDX\_LAB%' ESCAPE '\') LOOP
    EXECUTE IMMEDIATE 'DROP INDEX ' || i.index_name;
  END LOOP;

  -- Hak akun auditor dari percobaan sebelumnya dicabut
  FOR g IN (SELECT grantee, table_name, privilege FROM user_tab_privs_made WHERE grantee IN ('OPS_AUDIT', 'OPS_AUDITOR')) LOOP
    EXECUTE IMMEDIATE 'REVOKE ' || g.privilege || ' ON ' || g.table_name || ' FROM ' || g.grantee;
  END LOOP;

  -- Trigger audit dari Demo 2 dimatikan sementara, supaya data rusak tidak diperbaiki atau dicatat otomatis
  SELECT COUNT(*) INTO n FROM user_triggers WHERE trigger_name = 'TRG_INCIDENT_AUDIT';
  IF n = 1 THEN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_incident_audit DISABLE'; END IF;

  DELETE FROM incident_log WHERE incident_id IN
    (SELECT incident_id FROM incident
      WHERE incident_no IN ('INC-SIM-0006', 'INC-SIM-0009', 'INC-SIM-0017', 'INC-SIM-0020', 'INC-SIM-0022'));

  -- Skrip manual shift malam: status diubah tanpa transaksi dan tanpa cek aturan
  UPDATE incident SET status = 'RESOLVED', assigned_to = 'op.sari', closed_at = NULL,
         updated_at = TIMESTAMP '2026-11-16 15:30:00' WHERE incident_no = 'INC-SIM-0006';
  UPDATE incident SET status = 'CLOSED', assigned_to = 'op.andi', closed_at = NULL,
         updated_at = TIMESTAMP '2026-11-10 12:27:00' WHERE incident_no = 'INC-SIM-0009';
  UPDATE incident SET status = 'OPEN', assigned_to = 'op.budi', closed_at = NULL,
         updated_at = TIMESTAMP '2026-11-21 23:40:00' WHERE incident_no = 'INC-SIM-0017';
  UPDATE incident SET status = 'IN_PROGRESS', assigned_to = NULL, closed_at = NULL,
         updated_at = TIMESTAMP '2026-11-21 23:41:00' WHERE incident_no = 'INC-SIM-0020';
  UPDATE incident SET status = 'IN_PROGRESS', assigned_to = 'op.sari', closed_at = NULL,
         updated_at = TIMESTAMP '2026-11-08 18:51:00' WHERE incident_no = 'INC-SIM-0022';

  log_lab('INC-SIM-0006', 'IN_PROGRESS', 'RESOLVED', 'skrip.malam', TIMESTAMP '2026-11-16 15:30:00', 'Ubah status manual');
  log_lab('INC-SIM-0009', 'RESOLVED', 'CLOSED', 'skrip.malam', TIMESTAMP '2026-11-10 12:27:00', 'Ubah status manual');
  log_lab('INC-SIM-0017', 'IN_PROGRESS', 'OPEN', 'skrip.malam', TIMESTAMP '2026-11-21 23:40:00', 'Reset antrean manual');
  log_lab('INC-SIM-0020', 'OPEN', 'IN_PROGRESS', 'skrip.malam', TIMESTAMP '2026-11-21 23:41:00', 'Ubah status manual');
  log_lab('INC-SIM-0022', 'OPEN', 'IN_PROGRESS', 'op.dewi', TIMESTAMP '2026-11-08 18:50:00', 'Diambil operator');
  log_lab('INC-SIM-0022', 'OPEN', 'IN_PROGRESS', 'op.sari', TIMESTAMP '2026-11-08 18:51:00', 'Diambil dari layar lama');

  IF n = 1 THEN EXECUTE IMMEDIATE 'ALTER TRIGGER trg_incident_audit ENABLE'; END IF;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Insiden terpasang. Baca README bagian Lab, lalu mulai dari temuan 1.');
END;
/

SELECT incident_no, status, assigned_to, CASE WHEN closed_at IS NULL THEN '-' ELSE 'ADA' END AS closed_at
FROM incident
WHERE incident_no IN ('INC-SIM-0006', 'INC-SIM-0009', 'INC-SIM-0017', 'INC-SIM-0020', 'INC-SIM-0022')
ORDER BY incident_no;

SELECT COUNT(*) AS jumlah_incident FROM incident;
