-- Sesi 10 · Lab: cek otomatis pemulihan insiden (80 poin otomatis; 20 poin dinilai manual)
-- Cara pakai (PowerShell dan terminal macOS sama), dari folder `lab`:
--   docker cp cek-lab.sql oracle-xe:/tmp/cek-lab.sql
--   docker exec -it oracle-xe sqlplus / as sysdba @/tmp/cek-lab.sql
-- COMMIT dulu perbaikan di SQL Developer: cek memakai session lain, jadi hanya melihat data yang sudah di-commit.
-- Tidak mengubah data: procedure, function, dan trigger tim diuji di dalam savepoint lalu di-ROLLBACK, dan
-- COMMIT, ROLLBACK, serta DDL dari dalam PL/SQL dikunci (ALTER SESSION DISABLE COMMIT IN PROCEDURE).
-- Nomor sequence log yang terpakai saat uji tidak kembali (normal).

SET VERIFY OFF FEEDBACK OFF LINESIZE 100 TAB OFF TRIMSPOOL ON
SET EXITCOMMIT OFF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION DISABLE COMMIT IN PROCEDURE;
-- SERVEROUTPUT dinyalakan setelah pindah container, supaya output tidak hilang
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  TYPE t_teks IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
  catatan     t_teks;
  total       PLS_INTEGER := 0;
  insiden     BOOLEAN;
  n           NUMBER;
  m           NUMBER;
  k           NUMBER;
  ok          BOOLEAN;

  -- B: serah terima
  b_ada       BOOLEAN := FALSE;
  b_boleh_uji BOOLEAN := FALSE;
  b_sah       BOOLEAN := FALSE;
  b_commit    BOOLEAN := FALSE;
  terkunci    BOOLEAN := FALSE;
  pesan       VARCHAR2(200);
  t_no        VARCHAR2(20);
  t_op        VARCHAR2(30);
  r_no        VARCHAR2(20);
  c_no        VARCHAR2(20);
  p1          PLS_INTEGER := 0;
  p2          PLS_INTEGER := 0;
  hasil       VARCHAR2(40);

  PROCEDURE judul(t VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(t);
  END;

  PROCEDURE baris(k VARCHAR2, p PLS_INTEGER, maks PLS_INTEGER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD(k, 49) || LPAD(p, 3) || ' / ' || LPAD(maks, 2));
    total := total + p;
  END;

  PROCEDURE catat(t VARCHAR2) IS
  BEGIN
    catatan(catatan.COUNT + 1) := SUBSTR(t, 1, 200);
  END;

  FUNCTION satu(p_sql VARCHAR2) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    EXECUTE IMMEDIATE p_sql INTO v;
    RETURN v;
  END;

  FUNCTION objek_ok(p_nama VARCHAR2, p_tipe VARCHAR2) RETURN BOOLEAN IS
    v NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v FROM dba_objects
     WHERE owner = 'OPS_LAB' AND object_name = p_nama AND object_type = p_tipe AND status = 'VALID';
    RETURN v = 1;
  END;

  FUNCTION definer(p_nama VARCHAR2) RETURN BOOLEAN IS
    v NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v FROM dba_procedures
     WHERE owner = 'OPS_LAB' AND object_name = p_nama AND authid = 'CURRENT_USER';
    RETURN v = 0;
  END;

  -- Panggil handover_incident tim. Hasil: 0 = sukses, selain itu SQLCODE.
  FUNCTION panggil(p_no VARCHAR2, p_dari VARCHAR2, p_ke VARCHAR2) RETURN NUMBER IS
  BEGIN
    EXECUTE IMMEDIATE 'BEGIN ops_lab.handover_incident(:1, :2, :3); END;' USING p_no, p_dari, p_ke;
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -34 THEN b_commit := TRUE; END IF;
      pesan := SUBSTR(REGEXP_SUBSTR(SQLERRM, '^[^' || CHR(10) || ']*'), 1, 200);
      RETURN SQLCODE;
  END;

  FUNCTION aturan_bisnis(p_kode NUMBER) RETURN BOOLEAN IS
  BEGIN
    RETURN p_kode BETWEEN -20999 AND -20000;
  END;

  PROCEDURE keadaan(p_no VARCHAR2, p_hasil OUT VARCHAR2) IS
  BEGIN
    SELECT status || '/' || assigned_to || '/' ||
           (SELECT COUNT(*) FROM ops_lab.incident_log l WHERE l.incident_id = i.incident_id)
      INTO p_hasil FROM ops_lab.incident i WHERE incident_no = p_no;
  END;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users WHERE username = 'OPS_LAB';
  IF n = 0 THEN
    judul('User OPS_LAB tidak ada di XEPDB1. Selesaikan persiapan lab dulu.');
    RETURN;
  END IF;

  SELECT COUNT(*) INTO n FROM ops_lab.incident_log WHERE note LIKE '%[LAB]%';
  insiden := n >= 6;
  IF NOT insiden THEN
    catat('Insiden belum terpasang atau log insiden terhapus: jalankan 00-insiden.sql. Semua kriteria 0.');
  END IF;

  SELECT COUNT(*) INTO n FROM v$transaction t JOIN v$session s ON s.saddr = t.ses_addr
   WHERE s.username = 'OPS_LAB';
  IF n > 0 THEN
    catat('Ada ' || n || ' transaksi OPS_LAB yang belum di-COMMIT/ROLLBACK. Selesaikan, lalu jalankan cek lagi.');
  END IF;

  -- Tiket contoh untuk uji perilaku (dipilih dari 30 tiket asli)
  SELECT MIN(incident_no) INTO t_no FROM ops_lab.incident
   WHERE status = 'IN_PROGRESS' AND assigned_to IS NOT NULL AND incident_no NOT LIKE 'INC-SIM-B%';
  SELECT MIN(incident_no) INTO r_no FROM ops_lab.incident
   WHERE status = 'RESOLVED' AND incident_no NOT LIKE 'INC-SIM-B%';
  SELECT MIN(incident_no) INTO c_no FROM ops_lab.incident
   WHERE status = 'CLOSED' AND incident_no NOT LIKE 'INC-SIM-B%';
  -- Kalau baris uji masih dikunci session lain, uji perilaku dilewati supaya cek tidak menggantung
  BEGIN
    SAVEPOINT cek_kunci;
    FOR r IN (SELECT incident_id FROM ops_lab.incident
               WHERE incident_no IN (t_no, r_no, c_no) FOR UPDATE NOWAIT) LOOP
      NULL;
    END LOOP;
    ROLLBACK TO SAVEPOINT cek_kunci;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO SAVEPOINT cek_kunci;
      IF SQLCODE <> -54 THEN RAISE; END IF;
      terkunci := TRUE;
      catat('B dan C2-C3 tidak diuji: baris masih dikunci session lain (ORA-00054). COMMIT/ROLLBACK dulu.');
  END;

  judul('Cek Lab IT Ops 10 - schema OPS_LAB (XEPDB1)');
  judul(RPAD('Kriteria', 49) || 'Poin');
  judul(RPAD('-', 57, '-'));

  -- ===== A. Pemulihan data (20) =====
  judul('A. Pemulihan data');
  -- Nilai yang diharapkan diturunkan dari riwayat insiden di incident_log
  p1 := 0;
  SELECT COUNT(*) INTO n FROM ops_lab.incident i
   WHERE i.incident_no IN ('INC-SIM-0006', 'INC-SIM-0009')
     AND i.status = DECODE(i.incident_no, 'INC-SIM-0006', 'RESOLVED', 'CLOSED')
     AND i.closed_at = (SELECT MAX(l.changed_at) FROM ops_lab.incident_log l
                         WHERE l.incident_id = i.incident_id AND l.note LIKE '%[LAB]%');
  IF insiden THEN p1 := 3 * n; END IF;
  baris('A1 closed_at tiket 0006 dan 0009', p1, 6);

  SELECT COUNT(*) INTO n FROM ops_lab.incident
   WHERE incident_no = 'INC-SIM-0017' AND status = 'OPEN' AND assigned_to IS NULL AND closed_at IS NULL;
  baris('A2 tiket OPEN tanpa operator (0017)', CASE WHEN insiden THEN 3 * n ELSE 0 END, 3);

  SELECT COUNT(*) INTO n FROM ops_lab.incident
   WHERE incident_no = 'INC-SIM-0020' AND status = 'OPEN' AND assigned_to IS NULL AND closed_at IS NULL;
  baris('A3 tiket tanpa operator kembali OPEN (0020)', CASE WHEN insiden THEN 3 * n ELSE 0 END, 3);

  SELECT COUNT(*) INTO n FROM ops_lab.incident i
   WHERE i.incident_no = 'INC-SIM-0022' AND i.status = 'IN_PROGRESS'
     AND i.assigned_to = (SELECT MIN(l.changed_by) KEEP (DENSE_RANK FIRST ORDER BY l.changed_at)
                            FROM ops_lab.incident_log l
                           WHERE l.incident_id = i.incident_id AND l.note LIKE '%[LAB]%');
  baris('A4 pemegang sah tiket tertimpa (0022)', CASE WHEN insiden THEN 4 * n ELSE 0 END, 4);

  SELECT COUNT(*),
         NVL(SUM(CASE WHEN (status IN ('RESOLVED', 'CLOSED') AND closed_at IS NULL)
                        OR (status = 'OPEN' AND (assigned_to IS NOT NULL OR closed_at IS NOT NULL))
                        OR (status = 'IN_PROGRESS' AND assigned_to IS NULL) THEN 1 ELSE 0 END), 0)
    INTO n, m
    FROM ops_lab.incident WHERE incident_no NOT LIKE 'INC-SIM-B%';
  baris('A5 30 tiket asli utuh, 0 pelanggaran aturan',
        CASE WHEN insiden AND n = 30 AND m = 0 THEN 4 ELSE 0 END, 4);
  IF insiden AND (n <> 30 OR m <> 0) THEN
    catat('A5: tiket asli ' || n || ' (harus 30), pelanggaran aturan ' || m || ' (harus 0). Sudah COMMIT?');
  END IF;

  -- ===== B. Serah terima (18) =====
  judul('B. Procedure handover_incident');
  b_ada := insiden AND objek_ok('HANDOVER_INCIDENT', 'PROCEDURE');
  baris('B1 procedure ada dan VALID', CASE WHEN b_ada THEN 2 ELSE 0 END, 2);

  b_boleh_uji := b_ada;
  IF b_ada AND NOT definer('HANDOVER_INCIDENT') THEN
    b_boleh_uji := FALSE;
    catat('B: procedure memakai AUTHID CURRENT_USER, tidak diuji. Pakai default (definer).');
  END IF;
  IF b_boleh_uji AND terkunci THEN
    b_boleh_uji := FALSE;
  ELSIF b_boleh_uji AND t_no IS NULL THEN
    b_boleh_uji := FALSE;
    catat('B: tidak ada tiket IN_PROGRESS untuk diuji.');
  END IF;
  IF b_boleh_uji THEN
    SELECT assigned_to INTO t_op FROM ops_lab.incident WHERE incident_no = t_no;
  END IF;

  p1 := 0;
  IF b_boleh_uji THEN
    SAVEPOINT cek_b;
    SELECT COUNT(*) INTO m FROM ops_lab.incident_log l JOIN ops_lab.incident i ON i.incident_id = l.incident_id
     WHERE i.incident_no = t_no;
    k := panggil(t_no, t_op, 'op.cek');
    IF k = 0 THEN
      SELECT COUNT(*) INTO n FROM ops_lab.incident
       WHERE incident_no = t_no AND status = 'IN_PROGRESS' AND assigned_to = 'op.cek';
      IF n = 1 THEN p1 := 4; b_sah := TRUE; END IF;
      SELECT COUNT(*) INTO n FROM ops_lab.incident_log l JOIN ops_lab.incident i ON i.incident_id = l.incident_id
       WHERE i.incident_no = t_no;
      IF b_sah AND n = m + 1 THEN p1 := p1 + 2; END IF;
      IF n <> m + 1 THEN catat('B2: serah terima sah harus menambah tepat 1 baris incident_log.'); END IF;
    ELSE
      catat('B2: serah terima sah ' || t_no || ' dari ' || t_op || ' gagal: ' || pesan);
    END IF;
    ROLLBACK TO SAVEPOINT cek_b;
  END IF;
  baris('B2 serah terima sah berhasil dan tercatat', p1, 6);

  p1 := 0;
  IF b_sah THEN
    SAVEPOINT cek_b;
    keadaan(t_no, hasil);
    k := panggil(t_no, 'op.salah', 'op.cek');
    DECLARE
      sesudah VARCHAR2(40);
    BEGIN
      keadaan(t_no, sesudah);
      IF aturan_bisnis(k) AND sesudah = hasil THEN p1 := 5; END IF;
    END;
    ROLLBACK TO SAVEPOINT cek_b;
    IF p1 = 0 THEN catat('B3: pemegang salah harus ditolak RAISE_APPLICATION_ERROR tanpa mengubah data.'); END IF;
  END IF;
  baris('B3 pemegang salah ditolak, data tidak berubah', p1, 5);

  p1 := 0;
  IF b_sah THEN
    SAVEPOINT cek_b;
    SELECT NVL(MIN(assigned_to), 'op.cek') INTO hasil FROM ops_lab.incident WHERE incident_no = r_no;
    IF r_no IS NOT NULL AND aturan_bisnis(panggil(r_no, hasil, 'op.cek')) THEN p1 := 1; END IF;
    ROLLBACK TO SAVEPOINT cek_b;
    IF aturan_bisnis(panggil('INC-SIM-9999', 'op.cek', 'op.uji')) THEN p1 := p1 + 1; END IF;
    ROLLBACK TO SAVEPOINT cek_b;
  END IF;
  baris('B4 tiket bukan IN_PROGRESS / tidak ada ditolak', p1, 2);

  p1 := 0;
  IF b_sah THEN
    DECLARE
      src VARCHAR2(32767);
    BEGIN
      FOR r IN (SELECT text FROM dba_source
                 WHERE owner = 'OPS_LAB' AND name = 'HANDOVER_INCIDENT' AND type = 'PROCEDURE' ORDER BY line) LOOP
        src := SUBSTR(src || ' ' || REGEXP_REPLACE(RTRIM(r.text, CHR(10)), '--.*$', ''), 1, 32000);
      END LOOP;
      n := CASE WHEN REGEXP_LIKE(REGEXP_REPLACE(src, '/\*.*?\*/', ' '), 'FOR\s+UPDATE', 'i') THEN 1 ELSE 0 END;
    END;
    IF n = 1 AND NOT b_commit THEN p1 := 3; END IF;
    IF n = 0 THEN catat('B5: procedure belum mengunci baris dengan SELECT ... FOR UPDATE.'); END IF;
  END IF;
  IF b_commit THEN
    catat('B: procedure menjalankan COMMIT/ROLLBACK (ORA-00034 saat diuji). Pemanggil yang menentukan COMMIT.');
  END IF;
  baris('B5 baris dikunci, tanpa COMMIT/ROLLBACK', p1, 3);

  -- ===== C. Penjaga data (12) =====
  judul('C. Function dan trigger penjaga');
  p1 := 0;
  m := 0;
  IF insiden AND objek_ok('ACTIVE_INCIDENT_COUNT', 'FUNCTION') AND definer('ACTIVE_INCIDENT_COUNT') THEN
    FOR s IN (SELECT column_value AS kode FROM TABLE(sys.odcivarchar2list(
              'SVC-SIM-01', 'SVC-SIM-02', 'SVC-SIM-03', 'SVC-SIM-04', 'SVC-SIM-05', 'SVC-SIM-99'))) LOOP
      BEGIN
        SAVEPOINT cek_c;
        EXECUTE IMMEDIATE 'BEGIN :r := ops_lab.active_incident_count(:s); END;' USING OUT n, IN s.kode;
        SELECT COUNT(*) INTO k FROM ops_lab.incident i JOIN ops_lab.service v ON v.service_id = i.service_id
         WHERE v.service_code = s.kode AND i.status IN ('OPEN', 'IN_PROGRESS');
        IF n = k THEN m := m + 1; END IF;
        ROLLBACK TO SAVEPOINT cek_c;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO SAVEPOINT cek_c;
          catat('C1: ' || s.kode || ' gagal: ' || SQLERRM);
      END;
    END LOOP;
    p1 := FLOOR(5 * m / 6);
    IF m < 6 THEN catat('C1: ' || m || ' dari 6 kode layanan cocok (termasuk kode tidak dikenal, hasil 0).'); END IF;
  END IF;
  baris('C1 active_incident_count benar (6 kode)', p1, 5);

  p1 := 0;
  p2 := 0;
  SELECT COUNT(*) INTO n FROM dba_triggers t
   WHERE t.owner = 'OPS_LAB' AND t.trigger_name = 'TRG_INCIDENT_GUARD' AND t.status = 'ENABLED';
  IF insiden AND NOT terkunci AND n = 1 AND objek_ok('TRG_INCIDENT_GUARD', 'TRIGGER') AND c_no IS NOT NULL THEN
    SAVEPOINT cek_c;
    BEGIN
      EXECUTE IMMEDIATE 'UPDATE ops_lab.incident SET status = ''OPEN'' WHERE incident_no = :1' USING c_no;
      catat('C2: tiket CLOSED ' || c_no || ' masih bisa dibuka lagi.');
    EXCEPTION
      WHEN OTHERS THEN
        IF aturan_bisnis(SQLCODE) THEN p1 := 5; ELSE catat('C2: ' || SQLERRM); END IF;
    END;
    ROLLBACK TO SAVEPOINT cek_c;
    IF p1 = 5 AND t_no IS NOT NULL THEN
      BEGIN
        EXECUTE IMMEDIATE 'UPDATE ops_lab.incident SET status = ''RESOLVED'' WHERE incident_no = :1' USING t_no;
        k := SQL%ROWCOUNT;
        EXECUTE IMMEDIATE 'UPDATE ops_lab.incident SET summary = summary WHERE incident_no = :1' USING c_no;
        IF k = 1 AND SQL%ROWCOUNT = 1 THEN p2 := 2; END IF;
      EXCEPTION
        WHEN OTHERS THEN catat('C3: perubahan yang sah ikut ditolak: ' || SQLERRM);
      END;
      ROLLBACK TO SAVEPOINT cek_c;
    END IF;
  END IF;
  baris('C2 trigger menolak membuka tiket CLOSED', p1, 5);
  baris('C3 perubahan lain tetap berjalan', p2, 2);

  -- ===== D. Hak akses (16) =====
  judul('D. Hak akses');
  SELECT COUNT(*) INTO n FROM (
    SELECT privilege FROM dba_tab_privs
     WHERE owner = 'OPS_LAB' AND table_name = 'INCIDENT' AND privilege IN ('INSERT', 'UPDATE', 'DELETE')
       AND grantee IN ('OPS_OPERATOR', 'OPS_AGENT', 'OPS_READONLY', 'OPS_VIEWER', 'OPS_AUDIT', 'OPS_AUDITOR', 'PUBLIC')
    UNION ALL
    SELECT privilege FROM dba_col_privs
     WHERE owner = 'OPS_LAB' AND table_name = 'INCIDENT'
       AND grantee IN ('OPS_OPERATOR', 'OPS_AGENT', 'OPS_READONLY', 'OPS_VIEWER', 'OPS_AUDIT', 'OPS_AUDITOR', 'PUBLIC'));
  baris('D1 tanpa INSERT/UPDATE/DELETE di incident', CASE WHEN insiden AND n = 0 THEN 4 ELSE 0 END, 4);

  SELECT COUNT(*) INTO n FROM dba_tab_privs
   WHERE owner = 'OPS_LAB' AND grantee = 'OPS_OPERATOR'
     AND ((table_name = 'INCIDENT' AND privilege = 'SELECT')
          OR (table_name = 'HANDOVER_INCIDENT' AND privilege = 'EXECUTE'));
  baris('D2 OPS_OPERATOR: SELECT dan EXECUTE handover', CASE WHEN insiden AND n = 2 THEN 3 ELSE 0 END, 3);

  SELECT COUNT(*) INTO n FROM dba_tab_privs
   WHERE owner = 'OPS_LAB' AND table_name IN ('INCIDENT', 'INCIDENT_LOG')
     AND grantee IN ('OPS_READONLY', 'OPS_VIEWER', 'PUBLIC');
  baris('D3 OPS_READONLY tanpa akses incident dan log', CASE WHEN insiden AND n = 0 THEN 2 ELSE 0 END, 2);

  SELECT COUNT(*) INTO n FROM dba_users WHERE username = 'OPS_AUDITOR';
  SELECT COUNT(*) INTO m FROM dba_role_privs WHERE grantee = 'OPS_AUDITOR' AND granted_role = 'OPS_AUDIT';
  -- dihitung setelah role dipakai: sudah punya hak baca atas objek OPS_LAB
  SELECT COUNT(*) INTO k FROM dba_tab_privs WHERE grantee IN ('OPS_AUDITOR', 'OPS_AUDIT') AND owner = 'OPS_LAB';
  ok := insiden AND n = 1 AND m = 1 AND k > 0;
  IF insiden AND n = 1 AND m = 1 AND k = 0 THEN
    catat('D4-D6: akun auditor ada, tetapi role OPS_AUDIT belum diberi hak baca (README bagian D).');
  END IF;
  baris('D4 user OPS_AUDITOR memakai role OPS_AUDIT', CASE WHEN ok THEN 3 ELSE 0 END, 3);

  p1 := 0;
  p2 := 0;
  IF ok THEN
    SELECT COUNT(*),
           NVL(SUM(CASE WHEN owner = 'OPS_LAB' AND privilege = 'SELECT'
                         AND table_name IN ('INCIDENT_LOG', 'V_INCIDENT_AUDIT') THEN 1 ELSE 0 END), 0)
      INTO n, m
      FROM (SELECT DISTINCT owner, table_name, privilege FROM dba_tab_privs
             WHERE grantee IN ('OPS_AUDITOR', 'OPS_AUDIT'));
    SELECT COUNT(*) INTO k FROM dba_col_privs WHERE grantee IN ('OPS_AUDITOR', 'OPS_AUDIT');
    IF n = 2 AND m = 2 AND k = 0 THEN
      SELECT COUNT(*) INTO k FROM dba_tab_columns
       WHERE owner = 'OPS_LAB' AND table_name = 'V_INCIDENT_AUDIT' AND column_name = 'SUMMARY';
      IF k = 0 THEN p1 := 3; ELSE catat('D5: v_incident_audit tidak boleh memuat kolom summary.'); END IF;
    ELSE
      catat('D5: hak objek auditor harus tepat 2: SELECT incident_log dan v_incident_audit.');
    END IF;

    SELECT COUNT(*), NVL(SUM(CASE WHEN privilege = 'CREATE SESSION' THEN 0 ELSE 1 END), 0) INTO n, m
      FROM dba_sys_privs WHERE grantee IN ('OPS_AUDITOR', 'OPS_AUDIT');
    SELECT COUNT(*) INTO k FROM dba_role_privs
     WHERE grantee IN ('OPS_AUDITOR', 'OPS_AUDIT') AND granted_role <> 'OPS_AUDIT';
    IF n >= 1 AND m = 0 AND k = 0 THEN p2 := 1; ELSE catat('D6: hak sistem auditor hanya CREATE SESSION.'); END IF;
  END IF;
  baris('D5 auditor hanya baca log dan view audit', p1, 3);
  baris('D6 hak sistem auditor hanya CREATE SESSION', p2, 1);

  -- ===== E. Laporan lambat (14) =====
  judul('E. Laporan antrean');
  p1 := 0;
  p2 := 0;
  hasil := '';
  SELECT COUNT(*) INTO n FROM ops_lab.incident WHERE incident_no LIKE 'INC-SIM-B%';
  IF insiden AND n < 200000 THEN
    catat('E: data bulk belum ada (' || n || ' baris). Jalankan ../demo-4/05-bulk-incident.sql, lalu cek lagi.');
  END IF;
  IF insiden AND n >= 200000 AND objek_ok('V_LAPORAN_ANTREAN', 'VIEW') THEN
    SELECT COUNT(*),
           NVL(SUM(CASE WHEN column_name IN ('INCIDENT_NO', 'PRIORITY', 'ASSIGNED_TO', 'OPENED_AT') THEN 1 ELSE 0 END), 0)
      INTO m, k FROM dba_tab_columns WHERE owner = 'OPS_LAB' AND table_name = 'V_LAPORAN_ANTREAN';
    IF m = 4 AND k = 4 THEN
      BEGIN
        EXECUTE IMMEDIATE q'[
          WITH acuan AS (
            SELECT incident_no, priority, assigned_to, opened_at FROM ops_lab.incident
             WHERE service_id = 3 AND UPPER(status) = 'IN_PROGRESS' AND TRUNC(opened_at, 'MM') = DATE '2026-09-01'),
          tim AS (SELECT incident_no, priority, assigned_to, opened_at FROM ops_lab.v_laporan_antrean)
          SELECT (SELECT COUNT(*) FROM (SELECT * FROM acuan MINUS SELECT * FROM tim))
               + (SELECT COUNT(*) FROM (SELECT * FROM tim MINUS SELECT * FROM acuan))
               + ABS((SELECT COUNT(*) FROM tim) - (SELECT COUNT(*) FROM acuan)),
                 (SELECT COUNT(*) FROM acuan) FROM dual]' INTO m, k;
        IF m = 0 AND k > 0 THEN p1 := 4; ELSE catat('E1: hasil view beda dari query lama (' || m || ' selisih).'); END IF;
      EXCEPTION
        WHEN OTHERS THEN catat('E1: ' || SQLERRM);
      END;
    ELSE
      catat('E1: kolom view harus incident_no, priority, assigned_to, opened_at.');
    END IF;
  END IF;
  baris('E1 v_laporan_antrean hasilnya sama', p1, 4);

  p2 := 0;
  k := NULL;
  IF p1 = 4 THEN
    DELETE FROM plan_table WHERE statement_id = 'cek-lab';
    EXECUTE IMMEDIATE 'EXPLAIN PLAN SET STATEMENT_ID = ''cek-lab'' FOR '
                   || 'SELECT * FROM ops_lab.v_laporan_antrean ORDER BY opened_at';
    SELECT COUNT(*) INTO n FROM plan_table
     WHERE statement_id = 'cek-lab' AND operation = 'TABLE ACCESS' AND options = 'FULL' AND object_name = 'INCIDENT';
    SELECT COUNT(*) INTO m FROM plan_table
     WHERE statement_id = 'cek-lab' AND operation = 'INDEX' AND object_name LIKE 'IDX\_LAB%' ESCAPE '\';
    SELECT cost INTO k FROM plan_table WHERE statement_id = 'cek-lab' AND id = 0;
    IF n = 0 AND m >= 1 THEN
      p2 := 6;
    ELSE
      catat('E2: plan masih TABLE ACCESS FULL atau tidak memakai index IDX_LAB... (cek lewat EXPLAIN PLAN).');
    END IF;
  END IF;
  baris('E2 plan memakai index IDX_LAB, tanpa full scan', p2, 6);
  baris('E3 cost plan laporan <= 150' || CASE WHEN k IS NOT NULL THEN ' (cost ' || k || ')' END,
        CASE WHEN p2 = 6 AND k <= 150 THEN 4 ELSE 0 END, 4);

  judul(RPAD('-', 57, '-'));
  judul(RPAD('Subtotal otomatis', 49) || LPAD(total, 3) || ' / 80');
  judul('Manual (20): laporan insiden 10, uji dua session 6, ulang 4.');
  IF catatan.COUNT > 0 THEN
    judul(' ');
    judul('Catatan:');
    FOR i IN 1 .. catatan.COUNT LOOP
      judul('- ' || catatan(i));
    END LOOP;
  END IF;
  ROLLBACK;
END;
/

ROLLBACK;
EXIT SUCCESS ROLLBACK
