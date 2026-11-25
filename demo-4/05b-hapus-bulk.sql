-- Sesi 10 · Hapus data uji massal dan index latihan (opsional, setelah Demo 4).
-- Jalankan sebagai OPS_LAB dengan Run Script (F5). Incident asli tidak ikut terhapus.
DELETE FROM incident WHERE incident_no LIKE 'INC-SIM-B%';
COMMIT;

BEGIN
  EXECUTE IMMEDIATE 'DROP INDEX idx_incident_status_prio_opened';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE <> -1418 THEN RAISE; END IF;  -- ORA-01418: index tidak ada
END;
/

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'INCIDENT', method_opt => 'FOR ALL COLUMNS SIZE 254');
END;
/

SELECT COUNT(*) AS jumlah_incident FROM incident;
