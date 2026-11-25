-- Catch-up sesi 7-9: schema latihan IT Operations (asset, service, incident, incident_log) + data contoh
-- Jalankan sebagai OPS_LAB (koneksi OPS_LAB @ XEPDB1), Run Script (F5). Aman diulang: tabel lama dihapus dulu.
-- Semua data fiktif: kode AST-SIM-, SVC-SIM-, INC-SIM-. Hasil akhir: ASSET 10, SERVICE 5, INCIDENT 30, INCIDENT_LOG 0.
SET DEFINE OFF
SET FEEDBACK OFF

-- 1. Bersihkan objek lama (tabel anak dulu, lalu function/procedure/view latihan, lalu sequence). Objek yang belum ada diabaikan.
BEGIN
  FOR t IN (SELECT column_value AS n FROM TABLE(sys.odcivarchar2list('INCIDENT_LOG', 'INCIDENT', 'SERVICE', 'ASSET'))) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.n || ' CASCADE CONSTRAINTS PURGE';
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE NOT IN (-942) THEN RAISE; END IF;
    END;
  END LOOP;
  FOR o IN (SELECT object_name AS n, object_type AS t FROM user_objects
            WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'VIEW')
              AND object_name IN ('ASSIGN_INCIDENT', 'ESCALATE_INCIDENT', 'SLA_TARGET_HOURS', 'INCIDENT_AGE_HOURS', 'V_INCIDENT_AKTIF')) LOOP
    EXECUTE IMMEDIATE 'DROP ' || o.t || ' ' || o.n;
  END LOOP;
  FOR s IN (SELECT column_value AS n FROM TABLE(sys.odcivarchar2list('SEQ_INCIDENT', 'SEQ_INCIDENT_LOG'))) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.n;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE NOT IN (-2289) THEN RAISE; END IF;
    END;
  END LOOP;
END;
/

-- 2. Tabel
CREATE TABLE asset (
  asset_id    NUMBER(6)     CONSTRAINT pk_asset PRIMARY KEY,
  asset_code  VARCHAR2(20)  NOT NULL CONSTRAINT uq_asset_code UNIQUE,
  asset_name  VARCHAR2(60)  NOT NULL,
  asset_type  VARCHAR2(10)  NOT NULL CONSTRAINT ck_asset_type CHECK (asset_type IN ('SERVER', 'LAPTOP', 'SWITCH')),
  location    VARCHAR2(30)  NOT NULL,
  status      VARCHAR2(12)  DEFAULT 'AKTIF' NOT NULL CONSTRAINT ck_asset_status CHECK (status IN ('AKTIF', 'MAINTENANCE', 'PENSIUN'))
);

CREATE TABLE service (
  service_id   NUMBER(6)     CONSTRAINT pk_service PRIMARY KEY,
  service_code VARCHAR2(20)  NOT NULL CONSTRAINT uq_service_code UNIQUE,
  service_name VARCHAR2(60)  NOT NULL,
  owner_team   VARCHAR2(30)  NOT NULL,
  asset_id     NUMBER(6)     CONSTRAINT fk_service_asset REFERENCES asset (asset_id)
);

CREATE TABLE incident (
  incident_id NUMBER(10)     CONSTRAINT pk_incident PRIMARY KEY,
  incident_no VARCHAR2(20)   NOT NULL CONSTRAINT uq_incident_no UNIQUE,
  service_id  NUMBER(6)      NOT NULL CONSTRAINT fk_incident_service REFERENCES service (service_id),
  asset_id    NUMBER(6)      CONSTRAINT fk_incident_asset REFERENCES asset (asset_id),
  category    VARCHAR2(12)   NOT NULL CONSTRAINT ck_incident_category CHECK (category IN ('JARINGAN', 'APLIKASI', 'PERANGKAT', 'AKSES', 'DATABASE')),
  priority    VARCHAR2(2)    NOT NULL CONSTRAINT ck_incident_priority CHECK (priority IN ('P1', 'P2', 'P3', 'P4')),
  status      VARCHAR2(12)   DEFAULT 'OPEN' NOT NULL CONSTRAINT ck_incident_status CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
  assigned_to VARCHAR2(30),
  summary     VARCHAR2(120)  NOT NULL,
  opened_at   TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  closed_at   TIMESTAMP,
  updated_at  TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE incident_log (
  log_id      NUMBER(10)     CONSTRAINT pk_incident_log PRIMARY KEY,
  incident_id NUMBER(10)     NOT NULL CONSTRAINT fk_log_incident REFERENCES incident (incident_id),
  old_status  VARCHAR2(12),
  new_status  VARCHAR2(12)   NOT NULL CONSTRAINT ck_log_new_status CHECK (new_status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
  changed_by  VARCHAR2(30)   NOT NULL,
  changed_at  TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  note        VARCHAR2(120)
);

CREATE SEQUENCE seq_incident START WITH 31 CACHE 1000;
CREATE SEQUENCE seq_incident_log START WITH 1 CACHE 20;

-- 3. Data contoh
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (1, 'AST-SIM-001', 'Server Portal 01', 'SERVER', 'DC-SIM-1', 'AKTIF');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (2, 'AST-SIM-002', 'Server Email 01', 'SERVER', 'DC-SIM-1', 'AKTIF');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (3, 'AST-SIM-003', 'Server Database 01', 'SERVER', 'DC-SIM-2', 'AKTIF');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (4, 'AST-SIM-004', 'Server Aplikasi 01', 'SERVER', 'DC-SIM-2', 'MAINTENANCE');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (5, 'AST-SIM-005', 'Laptop Operator 01', 'LAPTOP', 'KANTOR-SIM', 'AKTIF');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (6, 'AST-SIM-006', 'Laptop Operator 02', 'LAPTOP', 'KANTOR-SIM', 'AKTIF');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (7, 'AST-SIM-007', 'Laptop Cadangan 01', 'LAPTOP', 'KANTOR-SIM', 'PENSIUN');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (8, 'AST-SIM-008', 'Switch Inti 01', 'SWITCH', 'DC-SIM-1', 'AKTIF');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (9, 'AST-SIM-009', 'Switch Lantai 2', 'SWITCH', 'KANTOR-SIM', 'AKTIF');
INSERT INTO asset (asset_id, asset_code, asset_name, asset_type, location, status) VALUES (10, 'AST-SIM-010', 'Switch Lantai 3', 'SWITCH', 'KANTOR-SIM', 'AKTIF');

INSERT INTO service (service_id, service_code, service_name, owner_team, asset_id) VALUES (1, 'SVC-SIM-01', 'Portal Karyawan Contoh', 'Tim Aplikasi', 1);
INSERT INTO service (service_id, service_code, service_name, owner_team, asset_id) VALUES (2, 'SVC-SIM-02', 'Layanan Email Contoh', 'Tim Aplikasi', 2);
INSERT INTO service (service_id, service_code, service_name, owner_team, asset_id) VALUES (3, 'SVC-SIM-03', 'Aplikasi Tiket Contoh', 'Tim Aplikasi', 4);
INSERT INTO service (service_id, service_code, service_name, owner_team, asset_id) VALUES (4, 'SVC-SIM-04', 'Jaringan Kantor Contoh', 'Tim Jaringan', 8);
INSERT INTO service (service_id, service_code, service_name, owner_team, asset_id) VALUES (5, 'SVC-SIM-05', 'Basis Data Laporan Contoh', 'Tim Data', 3);

INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (1, 'INC-SIM-0001', 3, 4, 'APLIKASI', 'P3', 'OPEN', NULL, 'Halaman login portal lambat', TIMESTAMP '2026-11-18 08:15:00', NULL, TIMESTAMP '2026-11-18 08:15:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (2, 'INC-SIM-0002', 2, 2, 'APLIKASI', 'P2', 'OPEN', NULL, 'Email keluar tertahan', TIMESTAMP '2026-11-18 09:40:00', NULL, TIMESTAMP '2026-11-18 09:40:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (3, 'INC-SIM-0003', 1, 1, 'AKSES', 'P2', 'OPEN', NULL, 'Akun tidak bisa masuk setelah ganti sandi', TIMESTAMP '2026-11-19 10:05:00', NULL, TIMESTAMP '2026-11-19 10:05:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (4, 'INC-SIM-0004', 4, 9, 'JARINGAN', 'P1', 'OPEN', NULL, 'Switch lantai 2 tidak merespons', TIMESTAMP '2026-11-19 13:20:00', NULL, TIMESTAMP '2026-11-19 13:20:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (5, 'INC-SIM-0005', 5, 3, 'DATABASE', 'P3', 'IN_PROGRESS', 'op.andi', 'Laporan harian terlambat terbit', TIMESTAMP '2026-11-17 07:50:00', NULL, TIMESTAMP '2026-11-17 07:50:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (6, 'INC-SIM-0006', 1, 5, 'PERANGKAT', 'P4', 'RESOLVED', 'op.sari', 'Laptop operator tidak bisa cetak', TIMESTAMP '2026-11-16 14:00:00', TIMESTAMP '2026-11-16 15:30:00', TIMESTAMP '2026-11-16 15:30:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (7, 'INC-SIM-0007', 5, 9, 'DATABASE', 'P2', 'OPEN', NULL, 'Backup malam gagal', TIMESTAMP '2026-11-02 11:55:00', NULL, TIMESTAMP '2026-11-02 11:55:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (8, 'INC-SIM-0008', 2, 1, 'PERANGKAT', 'P4', 'CLOSED', 'op.sari', 'Laptop operator tidak bisa cetak', TIMESTAMP '2026-11-03 23:18:00', TIMESTAMP '2026-11-04 17:02:00', TIMESTAMP '2026-11-04 17:02:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (9, 'INC-SIM-0009', 1, 2, 'AKSES', 'P2', 'CLOSED', 'op.andi', 'Token login kedaluwarsa', TIMESTAMP '2026-11-09 12:00:00', TIMESTAMP '2026-11-10 12:27:00', TIMESTAMP '2026-11-10 12:27:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (10, 'INC-SIM-0010', 2, 2, 'JARINGAN', 'P4', 'RESOLVED', 'op.andi', 'Koneksi kantor putus-putus', TIMESTAMP '2026-11-05 12:56:00', TIMESTAMP '2026-11-05 20:06:00', TIMESTAMP '2026-11-05 20:06:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (11, 'INC-SIM-0011', 5, 4, 'PERANGKAT', 'P4', 'RESOLVED', 'op.budi', 'Disk server hampir penuh', TIMESTAMP '2026-11-05 01:01:00', TIMESTAMP '2026-11-06 05:51:00', TIMESTAMP '2026-11-06 05:51:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (12, 'INC-SIM-0012', 4, 8, 'APLIKASI', 'P3', 'IN_PROGRESS', 'op.andi', 'Aplikasi tiket error 500', TIMESTAMP '2026-11-10 01:32:00', NULL, TIMESTAMP '2026-11-10 01:32:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (13, 'INC-SIM-0013', 2, 8, 'JARINGAN', 'P3', 'CLOSED', 'op.sari', 'Switch lantai tidak merespons', TIMESTAMP '2026-11-03 04:32:00', TIMESTAMP '2026-11-04 02:21:00', TIMESTAMP '2026-11-04 02:21:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (14, 'INC-SIM-0014', 5, 2, 'JARINGAN', 'P2', 'CLOSED', 'op.andi', 'Switch lantai tidak merespons', TIMESTAMP '2026-11-06 16:46:00', TIMESTAMP '2026-11-07 14:29:00', TIMESTAMP '2026-11-07 14:29:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (15, 'INC-SIM-0015', 4, 6, 'APLIKASI', 'P2', 'RESOLVED', 'op.andi', 'Halaman login lambat', TIMESTAMP '2026-11-03 11:15:00', TIMESTAMP '2026-11-04 04:19:00', TIMESTAMP '2026-11-04 04:19:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (16, 'INC-SIM-0016', 1, 3, 'PERANGKAT', 'P4', 'IN_PROGRESS', 'op.andi', 'Perangkat tidak mengenali USB', TIMESTAMP '2026-11-08 01:16:00', NULL, TIMESTAMP '2026-11-08 01:16:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (17, 'INC-SIM-0017', 5, 10, 'JARINGAN', 'P4', 'OPEN', NULL, 'Latensi tinggi ke pusat data', TIMESTAMP '2026-11-08 07:25:00', NULL, TIMESTAMP '2026-11-08 07:25:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (18, 'INC-SIM-0018', 2, 1, 'JARINGAN', 'P4', 'OPEN', NULL, 'Koneksi kantor putus-putus', TIMESTAMP '2026-11-07 11:07:00', NULL, TIMESTAMP '2026-11-07 11:07:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (19, 'INC-SIM-0019', 3, 10, 'APLIKASI', 'P2', 'RESOLVED', 'op.budi', 'Notifikasi email tidak terkirim', TIMESTAMP '2026-11-09 12:54:00', TIMESTAMP '2026-11-10 03:04:00', TIMESTAMP '2026-11-10 03:04:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (20, 'INC-SIM-0020', 2, 1, 'APLIKASI', 'P3', 'IN_PROGRESS', 'op.budi', 'Halaman login lambat', TIMESTAMP '2026-11-07 22:24:00', NULL, TIMESTAMP '2026-11-07 22:24:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (21, 'INC-SIM-0021', 4, 3, 'AKSES', 'P1', 'CLOSED', 'op.dewi', 'Akun terkunci setelah ganti sandi', TIMESTAMP '2026-11-09 11:49:00', TIMESTAMP '2026-11-09 18:46:00', TIMESTAMP '2026-11-09 18:46:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (22, 'INC-SIM-0022', 2, 10, 'APLIKASI', 'P4', 'IN_PROGRESS', 'op.dewi', 'Halaman login lambat', TIMESTAMP '2026-11-08 18:44:00', NULL, TIMESTAMP '2026-11-08 18:44:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (23, 'INC-SIM-0023', 5, 7, 'APLIKASI', 'P4', 'CLOSED', 'op.sari', 'Aplikasi tiket error 500', TIMESTAMP '2026-11-03 09:19:00', TIMESTAMP '2026-11-03 17:52:00', TIMESTAMP '2026-11-03 17:52:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (24, 'INC-SIM-0024', 2, 9, 'DATABASE', 'P3', 'CLOSED', 'op.dewi', 'Query laporan lambat', TIMESTAMP '2026-11-06 16:13:00', TIMESTAMP '2026-11-07 19:11:00', TIMESTAMP '2026-11-07 19:11:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (25, 'INC-SIM-0025', 4, 10, 'AKSES', 'P3', 'RESOLVED', 'op.andi', 'Token login kedaluwarsa', TIMESTAMP '2026-11-06 04:58:00', TIMESTAMP '2026-11-07 10:41:00', TIMESTAMP '2026-11-07 10:41:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (26, 'INC-SIM-0026', 5, 5, 'AKSES', 'P2', 'OPEN', NULL, 'Akun terkunci setelah ganti sandi', TIMESTAMP '2026-11-10 01:17:00', NULL, TIMESTAMP '2026-11-10 01:17:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (27, 'INC-SIM-0027', 1, 2, 'PERANGKAT', 'P1', 'CLOSED', 'op.budi', 'Disk server hampir penuh', TIMESTAMP '2026-11-09 21:37:00', TIMESTAMP '2026-11-10 11:00:00', TIMESTAMP '2026-11-10 11:00:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (28, 'INC-SIM-0028', 3, 8, 'AKSES', 'P3', 'IN_PROGRESS', 'op.andi', 'Token login kedaluwarsa', TIMESTAMP '2026-11-04 00:36:00', NULL, TIMESTAMP '2026-11-04 00:36:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (29, 'INC-SIM-0029', 2, 9, 'PERANGKAT', 'P3', 'CLOSED', 'op.dewi', 'Disk server hampir penuh', TIMESTAMP '2026-11-06 21:27:00', TIMESTAMP '2026-11-07 20:32:00', TIMESTAMP '2026-11-07 20:32:00');
INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to, summary, opened_at, closed_at, updated_at)
VALUES (30, 'INC-SIM-0030', 4, 9, 'JARINGAN', 'P3', 'CLOSED', 'op.sari', 'Koneksi kantor putus-putus', TIMESTAMP '2026-11-09 19:44:00', TIMESTAMP '2026-11-10 00:32:00', TIMESTAMP '2026-11-10 00:32:00');

COMMIT;

SET FEEDBACK ON
SELECT (SELECT COUNT(*) FROM asset)        AS jumlah_asset,
       (SELECT COUNT(*) FROM service)      AS jumlah_service,
       (SELECT COUNT(*) FROM incident)     AS jumlah_incident,
       (SELECT COUNT(*) FROM incident_log) AS jumlah_log
FROM dual;
