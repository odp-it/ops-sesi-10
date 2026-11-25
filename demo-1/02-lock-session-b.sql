-- Sesi 10 · Demo 1 (1.6–1.12): Locking dan concurrency (SESSION B)
-- Buka file ini di editor kanan (Split Right) dengan koneksi OPS_LAB @ XEPDB1.
-- Jalankan dengan Run Statement setiap kali README meminta. Nomor langkah berurutan menurut waktu.

-- 1.7.2 Baca prioritas saat session A menahan lock: tampil langsung (SELECT tidak diblokir), nilainya P3 (versi lama)
SELECT incident_no, priority FROM incident WHERE incident_no = 'INC-SIM-0001';

-- 1.7.3 Ubah baris yang sama: statement BERPUTAR menunggu session A COMMIT atau ROLLBACK.
--      Jangan ditutup; kembali ke session A (1.7.4), lalu lihat hasilnya di sini.
UPDATE incident SET status = 'IN_PROGRESS', assigned_to = 'op.sari' WHERE incident_no = 'INC-SIM-0001';

-- 1.7.5 Setelah baris di atas selesai: cek, lalu lepaskan perubahan session B juga
SELECT incident_no, priority, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0001';
ROLLBACK;

-- 1.8.2 Session B membaca incident yang sama: OPEN, belum ada yang mengambil
SELECT incident_no, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0003';

-- 1.8.4 (setelah 1.8.3 di session A) Session B menulis berdasarkan bacaan LAMA. Tidak menunggu, karena lock A sudah lepas.
--      Hasilnya menimpa op.andi tanpa peringatan (lost update).
UPDATE incident SET status = 'IN_PROGRESS', assigned_to = 'op.sari', updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0003';
COMMIT;
SELECT incident_no, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0003';

-- 1.8.6 (setelah 1.8.5 di session A) Session B membaca lagi: OPEN
SELECT incident_no, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0003';

-- 1.8.8 (setelah 1.8.7 di session A) Tulis dengan syarat status masih OPEN.
--      Hasilnya 0 rows updated: session B tahu sudah didahului dan tidak menimpa.
UPDATE incident SET status = 'IN_PROGRESS', assigned_to = 'op.sari', updated_at = SYSTIMESTAMP
WHERE incident_no = 'INC-SIM-0003' AND status = 'OPEN';
ROLLBACK;

-- 1.9.2 Session A memegang FOR UPDATE (1.9.1). NOWAIT: gagal seketika, tidak menunggu
SELECT incident_no, status FROM incident WHERE incident_no = 'INC-SIM-0003' FOR UPDATE NOWAIT;

-- 1.9.3 WAIT 3: menunggu paling lama 3 detik, lalu menyerah dengan error
SELECT incident_no, status FROM incident WHERE incident_no = 'INC-SIM-0003' FOR UPDATE WAIT 3;

-- 1.9.4 SKIP LOCKED: lewati baris yang sedang dikunci (cocok untuk antrean tiket)
SELECT incident_no FROM incident
WHERE incident_no IN ('INC-SIM-0001', 'INC-SIM-0002', 'INC-SIM-0003')
FOR UPDATE SKIP LOCKED;
ROLLBACK;

-- 1.9.6 (setelah 1.9.5 di session A) NOWAIT berhasil, lalu lepaskan
SELECT incident_no, status FROM incident WHERE incident_no = 'INC-SIM-0003' FOR UPDATE NOWAIT;
ROLLBACK;

-- 1.10.2 (setelah 1.10.1 di session A) Session B mengunci INC-SIM-0002
UPDATE incident SET summary = summary || ' [B]' WHERE incident_no = 'INC-SIM-0002';

-- 1.10.4 (setelah 1.10.3 di session A) Session B meminta INC-SIM-0001 yang dikunci A.
--      Saling menunggu: Oracle memutus salah satu dengan ORA-00060 setelah beberapa detik.
UPDATE incident SET summary = summary || ' [B]' WHERE incident_no = 'INC-SIM-0001';

-- 1.10.5 Lepaskan semua (di kedua session)
ROLLBACK;

-- 1.11.1 Mulai transaksi SERIALIZABLE: foto data dibekukan sejak perintah ini. Baca prioritas INC-SIM-0002: P2
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT incident_no, priority FROM incident WHERE incident_no = 'INC-SIM-0002';

-- 1.11.3 (setelah 1.11.2 di session A) Baca lagi: masih P2 walau A sudah COMMIT P1. Lalu coba ubah baris yang sama.
SELECT incident_no, priority FROM incident WHERE incident_no = 'INC-SIM-0002';
UPDATE incident SET status = 'IN_PROGRESS' WHERE incident_no = 'INC-SIM-0002';

-- 1.11.4 Akhiri transaksi SERIALIZABLE
ROLLBACK;
SELECT incident_no, priority, status FROM incident WHERE incident_no = 'INC-SIM-0002';

-- 1.12.2 (setelah 1.12.1 di session A) Ubah baris yang sama: menunggu. Biarkan berputar sampai admin selesai (1.12.3 dan 1.12.4).
UPDATE incident SET status = 'IN_PROGRESS', assigned_to = 'op.sari' WHERE incident_no = 'INC-SIM-0001';

-- 1.12.6 Setelah session A mati: statement di atas selesai sendiri. Cek, lalu lepaskan perubahan session B.
SELECT incident_no, priority, status, assigned_to FROM incident WHERE incident_no = 'INC-SIM-0001';
ROLLBACK;

