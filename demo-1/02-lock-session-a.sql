-- Sesi 10 · Demo 1 (1.6–1.12): Locking dan concurrency (SESSION A)
-- Editor kiri, koneksi OPS_LAB @ XEPDB1. Session B = file 02-lock-session-b.sql di editor kanan (Split Right),
-- koneksi OPS_LAB juga: satu tab worksheet = satu session database.
-- Nomor langkah berurutan menurut waktu di KEDUA file. Jalankan SATU PERINTAH sekali jalan dengan Run Statement.
-- Semua langkah berakhir dengan ROLLBACK atau langkah "kembalikan", jadi data kembali seperti catch-up.

-- 1.7.1 Ubah prioritas tanpa COMMIT: baris INC-SIM-0001 terkunci oleh session A
UPDATE incident SET priority = 'P2' WHERE incident_no = 'INC-SIM-0001';

-- 1.7.4 (setelah 1.7.2 dan 1.7.3 di session B) Lepaskan lock
ROLLBACK;

-- 1.8.1 Session A membaca incident yang akan diambil
SELECT incident_no, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0003';

-- 1.8.3 (setelah 1.8.2 di session B) Session A mengambil incident (op.andi) dan menyimpannya
UPDATE incident SET status = 'IN_PROGRESS', assigned_to = 'op.andi', updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0003';
COMMIT;

-- 1.8.5 (setelah 1.8.4 di session B) Kembalikan seperti semula
UPDATE incident SET status = 'OPEN', assigned_to = NULL, updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0003';
COMMIT;

-- 1.8.7 (setelah 1.8.6 di session B) Session A mengambil incident lagi
UPDATE incident SET status = 'IN_PROGRESS', assigned_to = 'op.andi', updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0003';
COMMIT;

-- 1.8.9 (setelah 1.8.8 di session B) Kembalikan seperti semula
UPDATE incident SET status = 'OPEN', assigned_to = NULL, updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0003';
COMMIT;

-- 1.9.1 Kunci baris dengan SELECT ... FOR UPDATE (belum ada perubahan data)
SELECT incident_no, status FROM incident WHERE incident_no = 'INC-SIM-0003' FOR UPDATE;

-- 1.9.5 (setelah 1.9.2 sampai 1.9.4 di session B) Lepaskan lock
ROLLBACK;

-- 1.10.1 Deadlock langkah 1: session A mengunci INC-SIM-0001
UPDATE incident SET summary = summary || ' [A]' WHERE incident_no = 'INC-SIM-0001';

-- 1.10.3 (setelah 1.10.2 di session B) Session A meminta INC-SIM-0002 yang dikunci B: menunggu
UPDATE incident SET summary = summary || ' [A]' WHERE incident_no = 'INC-SIM-0002';

-- 1.10.5 Lepaskan semua (di kedua session)
ROLLBACK;

-- 1.11.2 (setelah 1.11.1 di session B) Session A mengubah prioritas INC-SIM-0002 dan menyimpannya
UPDATE incident SET priority = 'P1' WHERE incident_no = 'INC-SIM-0002';
COMMIT;

-- 1.11.5 (setelah 1.11.4 di session B) Kembalikan seperti semula
UPDATE incident SET priority = 'P2' WHERE incident_no = 'INC-SIM-0002';
COMMIT;

-- 1.12.1 Tahan lock lagi untuk dilihat admin: JANGAN COMMIT. Langkah 1.12 ada di README (session B menunggu, admin melihat).
UPDATE incident SET priority = 'P2' WHERE incident_no = 'INC-SIM-0001';

-- 1.12.5 Setelah admin mematikan session ini, tab ini tidak bisa dipakai lagi (ORA-00028): hubungkan ulang koneksinya.
--      Kalau tidak ada yang dimatikan, lepaskan lock dengan:
ROLLBACK;

