-- Sesi 10 · Demo 2: Function, procedure, dan trigger
-- Koneksi OPS_LAB @ XEPDB1. Blok PL/SQL (CREATE ... END;) dijalankan dengan Run Script (F5) pada blok yang diseleksi,
-- perintah SELECT/EXEC dengan Run Statement. Tanda "/" sendirian di satu baris menutup blok PL/SQL.

-- 2.1 Function: target SLA per prioritas dan umur incident dalam jam
CREATE OR REPLACE FUNCTION sla_target_hours (p_priority IN VARCHAR2)
RETURN NUMBER DETERMINISTIC
IS
BEGIN
  RETURN CASE p_priority WHEN 'P1' THEN 2 WHEN 'P2' THEN 4 WHEN 'P3' THEN 8 WHEN 'P4' THEN 24 END;
END sla_target_hours;
/

CREATE OR REPLACE FUNCTION incident_age_hours (
  p_opened_at IN TIMESTAMP,
  p_closed_at IN TIMESTAMP,
  p_now       IN TIMESTAMP DEFAULT SYSTIMESTAMP)
RETURN NUMBER
IS
BEGIN
  RETURN ROUND((CAST(NVL(p_closed_at, p_now) AS DATE) - CAST(p_opened_at AS DATE)) * 24, 1);
END incident_age_hours;
/

-- 2.1b Pakai function di query: incident OPEN yang sudah melewati target SLA (acuan waktu 20 Nov 2026 12.00)
SELECT incident_no, priority, sla_target_hours(priority) AS target_jam,
       incident_age_hours(opened_at, closed_at, TIMESTAMP '2026-11-20 12:00:00') AS umur_jam
FROM incident
WHERE status = 'OPEN'
  AND incident_age_hours(opened_at, closed_at, TIMESTAMP '2026-11-20 12:00:00') > sla_target_hours(priority)
ORDER BY umur_jam DESC;

-- 2.2 Procedure: ambil incident (assign). Satu unit kerja: cek, kunci baris, ubah, COMMIT; gagal = ROLLBACK
CREATE OR REPLACE PROCEDURE assign_incident (
  p_incident_no IN VARCHAR2,
  p_operator    IN VARCHAR2)
IS
  v_status incident.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM incident WHERE incident_no = p_incident_no FOR UPDATE;
  IF v_status <> 'OPEN' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Incident ' || p_incident_no || ' berstatus ' || v_status || ', hanya OPEN yang bisa diambil');
  END IF;
  UPDATE incident SET status = 'IN_PROGRESS', assigned_to = p_operator WHERE incident_no = p_incident_no;
  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20002, 'Incident ' || p_incident_no || ' tidak ditemukan');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END assign_incident;
/

CREATE OR REPLACE PROCEDURE escalate_incident (
  p_incident_no IN VARCHAR2,
  p_by          IN VARCHAR2)
IS
  v_id     incident.incident_id%TYPE;
  v_prio   incident.priority%TYPE;
  v_status incident.status%TYPE;
  v_new    incident.priority%TYPE;
BEGIN
  SELECT incident_id, priority, status INTO v_id, v_prio, v_status
  FROM incident WHERE incident_no = p_incident_no FOR UPDATE;
  IF v_status IN ('RESOLVED', 'CLOSED') THEN
    RAISE_APPLICATION_ERROR(-20003, 'Incident ' || p_incident_no || ' sudah ' || v_status || ', tidak bisa dieskalasi');
  END IF;
  IF v_prio = 'P1' THEN
    RAISE_APPLICATION_ERROR(-20004, 'Incident ' || p_incident_no || ' sudah P1');
  END IF;
  v_new := 'P' || (TO_NUMBER(SUBSTR(v_prio, 2)) - 1);
  UPDATE incident SET priority = v_new WHERE incident_id = v_id;
  INSERT INTO incident_log (log_id, incident_id, old_status, new_status, changed_by, note)
  VALUES (seq_incident_log.NEXTVAL, v_id, v_status, v_status, p_by, 'Eskalasi ' || v_prio || ' ke ' || v_new);
  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20002, 'Incident ' || p_incident_no || ' tidak ditemukan');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END escalate_incident;
/

-- 2.2b Panggil procedure
EXEC assign_incident('INC-SIM-0001', 'op.sari');
SELECT incident_no, priority, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0001';

-- 2.2c Dipanggil lagi: ditolak (sudah IN_PROGRESS), dan nomor yang tidak ada
EXEC assign_incident('INC-SIM-0001', 'op.andi');
EXEC assign_incident('INC-SIM-9999', 'op.andi');

-- 2.2d Eskalasi: prioritas naik satu tingkat dan tercatat di log
EXEC escalate_incident('INC-SIM-0001', 'op.sari');
SELECT incident_no, priority FROM incident WHERE incident_no = 'INC-SIM-0001';
SELECT log_id, old_status, new_status, changed_by, note FROM incident_log ORDER BY log_id;

-- 2.3 Trigger audit: DENGAN SALAH KETIK (:NEW.stats seharusnya :NEW.status). Jalankan apa adanya dulu.
CREATE OR REPLACE TRIGGER trg_incident_audit
BEFORE UPDATE ON incident
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
  IF :NEW.stats <> :OLD.status THEN
    INSERT INTO incident_log (log_id, incident_id, old_status, new_status, changed_by, note)
    VALUES (seq_incident_log.NEXTVAL, :NEW.incident_id, :OLD.status, :NEW.status,
            NVL(:NEW.assigned_to, SYS_CONTEXT('USERENV', 'SESSION_USER')), 'Trigger audit');
  END IF;
END trg_incident_audit;
/

-- 2.3b Baca error compile: dua cara
SHOW ERRORS TRIGGER trg_incident_audit

SELECT line, position, text FROM user_errors WHERE name = 'TRG_INCIDENT_AUDIT' ORDER BY sequence;
SELECT object_name, object_type, status FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE', 'TRIGGER') ORDER BY object_type, object_name;

-- 2.3c Akibat: trigger INVALID membuat SEMUA UPDATE di tabel incident gagal
UPDATE incident SET priority = 'P2' WHERE incident_no = 'INC-SIM-0002';

-- 2.3d Perbaiki (:NEW.stats jadi :NEW.status), tambah closed_at otomatis, lalu kompilasi ulang
CREATE OR REPLACE TRIGGER trg_incident_audit
BEFORE UPDATE ON incident
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
  IF :NEW.status <> :OLD.status THEN
    IF :NEW.status IN ('RESOLVED', 'CLOSED') AND :NEW.closed_at IS NULL THEN
      :NEW.closed_at := SYSTIMESTAMP;
    ELSIF :NEW.status IN ('OPEN', 'IN_PROGRESS') THEN
      :NEW.closed_at := NULL;
    END IF;
    INSERT INTO incident_log (log_id, incident_id, old_status, new_status, changed_by, note)
    VALUES (seq_incident_log.NEXTVAL, :NEW.incident_id, :OLD.status, :NEW.status,
            NVL(:NEW.assigned_to, SYS_CONTEXT('USERENV', 'SESSION_USER')), 'Trigger audit');
  END IF;
END trg_incident_audit;
/

SELECT object_name, status FROM user_objects WHERE object_type = 'TRIGGER';
SELECT COUNT(*) AS error_tersisa FROM user_errors WHERE name = 'TRG_INCIDENT_AUDIT';

-- 2.4 Uji trigger: incident berpindah status tanpa kita menulis INSERT log
EXEC assign_incident('INC-SIM-0002', 'op.andi');

UPDATE incident SET status = 'RESOLVED' WHERE incident_no = 'INC-SIM-0005';
COMMIT;

SELECT i.incident_no, i.status, CASE WHEN i.closed_at IS NULL THEN 'TIDAK' ELSE 'ADA' END AS closed_at
FROM incident i WHERE i.incident_no IN ('INC-SIM-0002', 'INC-SIM-0005') ORDER BY i.incident_no;
SELECT log_id, old_status, new_status, changed_by, note FROM incident_log ORDER BY log_id;
