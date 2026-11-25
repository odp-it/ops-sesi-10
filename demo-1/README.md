> Buka folder ini untuk bagian ini. Semua path relatif terhadap folder ini. Persiapan, troubleshooting, dan cleanup: [README utama](../README.md).

# Demo 1 · Transaksi dan Locking (±65 menit)

Instruktur memperagakan transaksi, row lock, lost update, `FOR UPDATE`, deadlock, dan sudut pandang admin dari dua session (±20 menit). Peserta lalu mengerjakan 1.1–1.12 dengan file di folder ini (±45 menit).

## Bagian A · Transaksi (1.1–1.5, ±13 menit)

Buka `01-transaksi.sql`, pasang koneksi `OPS_LAB @ XEPDB1`. Jalankan **satu perintah sekali jalan** dengan Run Statement, urut dari atas.

## 1.1 Cek data (±1 menit)

Jalankan query status. Yang harus terlihat: `CLOSED 10`, `IN_PROGRESS 6`, `OPEN 8`, `RESOLVED 6`.

## 1.2 Dua perintah, satu transaksi (±4 menit)

Mengambil incident berarti dua hal: status berubah dan riwayat dicatat. Jalankan `SELECT` awal, `UPDATE`, dan `INSERT`, lalu dua `SELECT` pengecekan. Yang harus terlihat: `INC-SIM-0004` berstatus `IN_PROGRESS` untuk `op.andi` dan `JUMLAH_LOG 1`, padahal belum ada `COMMIT`.

Jalankan `ROLLBACK` (1.2b). Yang harus terlihat: `INC-SIM-0004` kembali `OPEN` tanpa `assigned_to`, `JUMLAH_LOG 0`. Lalu jalankan 1.2c (kedua perintah lagi, kali ini diikuti `COMMIT`) dan `SELECT` log: satu baris. Perhatikan `LOG_ID`: angkanya `2`, bukan `1`. Sequence tidak ikut `ROLLBACK`.

## 1.3 Error di tengah transaksi (±3 menit)

Jalankan `UPDATE` ke `RESOLVED` untuk `INC-SIM-0003`, lalu `INSERT` log dengan status salah ketik `SELESAI`. Yang harus terlihat: `ORA-02290: check constraint (OPS_LAB.CK_LOG_NEW_STATUS) violated`. Jalankan `SELECT` status: `INC-SIM-0003` **masih** `RESOLVED` (UPDATE sebelumnya tidak ikut dibatalkan). Jalankan `ROLLBACK`: kembali `OPEN`.

## 1.4 SAVEPOINT (±3 menit)

Jalankan berurutan: `UPDATE` 0001 jadi P2, `SAVEPOINT`, `UPDATE` 0002 jadi P1, `ROLLBACK TO SAVEPOINT`. Yang harus terlihat: `INC-SIM-0001` P2 (tetap berubah), `INC-SIM-0002` P2 (dibatalkan). Lalu `ROLLBACK`: `INC-SIM-0001` kembali `P3`.

## 1.5 DDL = COMMIT otomatis (±2 menit)

Jalankan `UPDATE` summary 0001, `CREATE TABLE catatan_sementara`, lalu `ROLLBACK`. Yang harus terlihat: summary `Halaman login portal lambat (dicek)`, perubahan tetap ada walau sudah `ROLLBACK`. Kembalikan dengan 1.5b (UPDATE + `COMMIT` + `DROP TABLE`).

## Bagian B · Locking dan Concurrency (1.6–1.12, ±32 menit)

Satu tab worksheet = satu session database. Nomor langkah berurutan menurut waktu di **kedua** file.

## 1.6 Siapkan dua session (±2 menit)

1. Buka `02-lock-session-a.sql`, pasang koneksi `OPS_LAB @ XEPDB1` (**session A**).
2. Klik kanan tab, **Split Right**, lalu buka `02-lock-session-b.sql` di editor kanan dan pasang koneksi `OPS_LAB @ XEPDB1` (**session B**). Hapus tab file yang sama dari editor kanan kalau muncul dua.
3. Pastikan data sesuai catch-up: kalau langkah 1.1–1.5 sudah dikerjakan, tidak masalah (langkah locking memakai incident 0001–0003).

## 1.7 Row lock: session B menunggu (±5 menit)

1. Session A: 1.7.1 (`UPDATE ... priority = 'P2'`), **jangan** `COMMIT`. Yang harus terlihat: `1 row updated.`
2. Session B: 1.7.2 (`SELECT`). Yang harus terlihat: langsung tampil, prioritas `P3` (nilai lama). `SELECT` tidak diblokir.
3. Session B: 1.7.3 (`UPDATE` baris yang sama). Yang harus terlihat: statement **tidak selesai**, indikator berputar.
4. Session A: 1.7.4 (`ROLLBACK`). Yang harus terlihat di session B: `1 row updated.` muncul sendiri.
5. Session B: 1.7.5. Prioritas `P3`, status `IN_PROGRESS`, lalu `ROLLBACK`.

Catat: berapa detik session B menunggu, dan apa yang melepaskan lock.

## 1.8 Lost update: dua operator mengambil tiket yang sama (±7 menit)

1. Session A: 1.8.1. Session B: 1.8.2. Keduanya membaca `INC-SIM-0003`: `OPEN`, tanpa operator.
2. Session A: 1.8.3 (`op.andi` mengambil, `COMMIT`).
3. Session B: 1.8.4 (menulis dari bacaan lama: `op.sari`, `COMMIT`). Tidak menunggu. Yang harus terlihat: `assigned_to` `op.sari`. Pengambilan `op.andi` hilang tanpa peringatan.
4. Session A: 1.8.5 (kembalikan data). Session B: 1.8.6 (baca lagi: `OPEN`).
5. Session A: 1.8.7 (`op.andi` mengambil lagi). Session B: 1.8.8 (`UPDATE ... AND status = 'OPEN'`). Yang harus terlihat: `0 rows updated.` Session B tahu sudah didahului.
6. Session A: 1.8.9 (kembalikan data).

Kesimpulan: nilai yang ditulis dari bacaan lama menimpa perubahan orang lain. Cegah dengan syarat di `WHERE` (`AND status = 'OPEN'`) atau kunci baris dulu (1.9).

## 1.9 SELECT ... FOR UPDATE (±5 menit)

1. Session A: 1.9.1 (`SELECT ... FOR UPDATE`). Hasil: satu baris. Baris sekarang dikunci A.
2. Session B: 1.9.2 (`FOR UPDATE NOWAIT`). Yang harus terlihat: error langsung:

```text
ORA-00054: resource busy and acquire with NOWAIT specified or timeout expired
```

3. Session B: 1.9.3 (`FOR UPDATE WAIT 3`). Menunggu ±3 detik, lalu `ORA-30006: resource busy; acquire with WAIT timeout expired`.
4. Session B: 1.9.4 (`SKIP LOCKED`). Yang harus terlihat: `INC-SIM-0001` dan `INC-SIM-0002` (0003 dilewati karena dikunci), lalu `ROLLBACK`.
5. Session A: 1.9.5 (`ROLLBACK`). Session B: 1.9.6 (`NOWAIT` berhasil), lalu `ROLLBACK`.

Catat: `NOWAIT` gagal seketika, `WAIT n` menyerah setelah n detik, `SKIP LOCKED` melewati baris yang terkunci (cocok untuk antrean tiket).

## 1.10 Deadlock (±5 menit)

1. Session A: 1.10.1 (kunci 0001). Session B: 1.10.2 (kunci 0002).
2. Session A: 1.10.3 (minta 0002: menunggu).
3. Session B: 1.10.4 (minta 0001: saling menunggu). Setelah ±3 detik, **salah satu** session (bukan selalu A) menerima:

```text
ORA-00060: deadlock detected while waiting for resource
```

4. Hanya statement yang kena error yang dibatalkan, bukan seluruh transaksi. Jalankan 1.10.5 (`ROLLBACK`) di **kedua** session.

## 1.11 Isolation level SERIALIZABLE (±3 menit)

1. Session B: 1.11.1 (`SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`, lalu baca `INC-SIM-0002`: `P2`).
2. Session A: 1.11.2 (ubah ke `P1`, `COMMIT`).
3. Session B: 1.11.3. Yang harus terlihat: prioritas masih `P2` (foto data dibekukan), lalu `ORA-08177: can't serialize access for this transaction`.
4. Session B: 1.11.4 (`ROLLBACK`; prioritas sekarang `P1`). Session A: 1.11.5 (kembalikan ke `P2`).

Default Oracle adalah `READ COMMITTED`: setiap query melihat data yang sudah di-commit saat query dimulai (itu yang terlihat di 1.7 dan 1.8).

## 1.12 Admin melihat dan mematikan session penahan (±5 menit)

1. Session A: 1.12.1 (`UPDATE`, tanpa `COMMIT`). Session B: 1.12.2 (`UPDATE` baris yang sama: menunggu).
2. Buka terminal. Dari folder `demo-1` (admin, bukan SQL Developer):

```powershell
docker cp setup/02-admin-lihat-lock.sql oracle-xe:/tmp/02-admin-lihat-lock.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/02-admin-lihat-lock.sql
```

Yang harus terlihat (1.12.3): dua baris `OPS_LAB` di `V$SESSION`, session yang menunggu berisi `BLOCKER` dan event `enq: TX - row lock contention`; di `V$LOCK` baris `TX` dengan `BLOCK` `1` milik session penahan; dan teks `UPDATE` yang ditunggu.

3. 1.12.4: catat `SID,SERIAL#` session penahan (baris dengan `BLOCKER` kosong), lalu matikan:

```powershell
docker cp setup/03-admin-matikan-session.sql oracle-xe:/tmp/03-admin-matikan-session.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/03-admin-matikan-session.sql
```

Ketik `SID,SERIAL#` saat diminta. Yang harus terlihat: `System altered.`

4. 1.12.5: di session A, jalankan perintah apa pun: `ORA-00028: your session has been killed`. Transaksi A di-`ROLLBACK` otomatis. Pasang ulang koneksi di tab A.
5. 1.12.6: di session B, `UPDATE` selesai sendiri (`1 row updated.`). Cek, lalu `ROLLBACK`.

Mematikan session hanya untuk database latihan dan kasus mendesak; di database kantor lakukan lewat prosedur DBA.

## Tantangan tambahan Demo 1 (opsional)

Untuk tim yang selesai lebih cepat. Tulis sendiri perintahnya (file kosong boleh), lalu cocokkan dengan expected.

**T1.1 Antrean tiket tanpa saling tunggu (±6 menit).** Dua operator mengambil tiket `OPEN` terdepan secara bersamaan tanpa saling tunggu. Di kedua session jalankan blok berikut dengan Run Script (seleksi seluruh blok sampai `/`), session A dulu, jangan `COMMIT`:

```sql
SET SERVEROUTPUT ON
DECLARE
  CURSOR c IS SELECT incident_no FROM incident WHERE status = 'OPEN' ORDER BY incident_id FOR UPDATE SKIP LOCKED;
  v incident.incident_no%TYPE;
BEGIN
  OPEN c;
  FETCH c INTO v;
  DBMS_OUTPUT.PUT_LINE('Diambil: ' || v);
  CLOSE c;
END;
/
```

Yang harus terlihat: session A `Diambil: INC-SIM-0001`, session B `Diambil: INC-SIM-0002` (tiket yang dikunci A dilewati, B tidak menunggu). Akhiri dengan `ROLLBACK` di kedua session. Tulis satu kalimat: kenapa `FETCH FIRST 1 ROWS ONLY` atau `ROWNUM = 1` bersama `FOR UPDATE SKIP LOCKED` tidak dipakai di sini.

**T1.2 Hindari deadlock dengan urutan kunci yang sama (±6 menit).** Ulangi skenario deadlock 1.10, tetapi kali ini kedua session mengunci `INC-SIM-0001` lebih dulu, baru `INC-SIM-0002` (`summary = summary || ' [A]'` atau `' [B]'`). Session A: `UPDATE` 0001 lalu 0002, belum `COMMIT`. Session B: `UPDATE` 0001. Yang harus terlihat: session B menunggu (tidak ada `ORA-00060`); setelah session A `ROLLBACK`, `UPDATE` session B selesai (`1 row updated.`), lalu `UPDATE` 0002 juga berhasil. `ROLLBACK` di kedua session. Aturan yang dicatat: semua transaksi mengunci baris dalam urutan yang sama.
