# Lab · Pemulihan Insiden Operasi

[Persiapan](../README.md) · [Troubleshooting](../TROUBLESHOOTING.md)

**Skenario.** Senin pagi, tim operasi menerima lima laporan setelah shift akhir pekan (fiktif): data tiket tidak konsisten karena skrip manual dijalankan tanpa transaksi, satu tiket berpindah operator tanpa sepengetahuan pemegangnya, tiket yang sudah `CLOSED` bisa dibuka lagi, audit menemukan role operator punya hak `UPDATE` dan `DELETE` langsung, dan laporan antrean di dashboard lambat. Tim bertugas sebagai DBA piket: perbaiki, cegah terulang, dan buktikan.

Satu laptop per tim, schema `OPS_LAB` milik laptop itu. Prasyarat: role dari 3.1 sudah dibuat, dan data bulk dari 4.2 sudah dimuat (`JUMLAH_INCIDENT 200030`; kalau belum, jalankan `../demo-4/05-bulk-incident.sql`).

## L1. Pasang insiden

1. Pastikan tidak ada transaksi terbuka (`COMMIT` atau `ROLLBACK` di semua tab).
2. Buka `00-insiden.sql`, koneksi `OPS_LAB @ XEPDB1`, **F5**. Yang harus terlihat: `Insiden terpasang.`, lima tiket dalam keadaan rusak, dan `JUMLAH_INCIDENT 200030`. Skrip ini aman diulang: menjalankannya lagi mengembalikan insiden dari awal dan menghapus objek Lab sebelumnya.
3. Salin `perbaikan-tim.sql` menjadi `perbaikan-<nama-tim>.sql`, `admin-auditor-tim.sql` menjadi `admin-auditor-<nama-tim>.sql`, dan `laporan-insiden-tim.md` menjadi `laporan-insiden-<nama-tim>.md`.

## A. Pemulihan data, satu transaksi

Aturan data yang berlaku untuk tiket:

| Status | Aturan |
| --- | --- |
| `RESOLVED`, `CLOSED` | `closed_at` terisi. Kalau kosong, isi dengan `updated_at` tiket itu |
| `OPEN` | `assigned_to` dan `closed_at` kosong |
| `IN_PROGRESS` | `assigned_to` terisi. Kalau kosong, kembalikan jadi `OPEN` |
| Tiket tertimpa | `INC-SIM-0022`: pemegang sah adalah operator yang **pertama** mengambil menurut `incident_log` |

Kerjakan dalam satu transaksi: `SAVEPOINT`, perbaiki, jalankan query pencari pelanggaran (harus 0 baris), baru `COMMIT`. Jangan menghapus tiket atau baris `incident_log`.

## B. Serah terima aman: handover_incident

Buat procedure `handover_incident(p_incident_no IN VARCHAR2, p_from_operator IN VARCHAR2, p_to_operator IN VARCHAR2)`:

1. Kunci baris tiket dengan `SELECT ... FOR UPDATE`.
2. Tolak dengan `RAISE_APPLICATION_ERROR` (kode `-20000` s.d. `-20999`) bila tiket tidak ada, statusnya bukan `IN_PROGRESS`, atau pemegangnya bukan `p_from_operator`.
3. Ubah `assigned_to` menjadi `p_to_operator`, lalu tambah satu baris `incident_log` (status lama dan baru `IN_PROGRESS`, `changed_by` = `p_from_operator`, `note` berisi serah terima).
4. **Tanpa `COMMIT` dan `ROLLBACK`** di dalam procedure: pemanggil yang menentukan.

Uji dari dua session dengan `INC-SIM-0012` (dipegang `op.andi`) dan catat di laporan: A menjalankan serah terima ke `op.sari` tanpa `COMMIT`; B menjalankan serah terima `op.andi` ke `op.dewi` (menunggu); A `COMMIT`; catat apa yang diterima B. Akhiri dengan `ROLLBACK` di B.

## C. Penjaga data

1. Function `active_incident_count(p_service_code IN VARCHAR2) RETURN NUMBER`: jumlah tiket `OPEN` dan `IN_PROGRESS` untuk kode layanan itu; kode yang tidak dikenal menghasilkan `0`.
2. Trigger `trg_incident_guard` (`BEFORE UPDATE`, `FOR EACH ROW`): status `CLOSED` tidak boleh berubah lagi (`RAISE_APPLICATION_ERROR`). Perubahan kolom lain dan perubahan status tiket lain tetap boleh.

## D. Hak akses minimum

1. Cari hak berlebih di `USER_TAB_PRIVS_MADE`, lalu cabut **hanya** yang berlebih: `OPS_OPERATOR` tidak boleh `INSERT`, `UPDATE`, `DELETE` di `incident`; `OPS_READONLY` tidak boleh membaca `incident` dan `incident_log`. `SELECT` di `incident` untuk `OPS_OPERATOR` tetap ada.
2. `OPS_OPERATOR` boleh `EXECUTE` `handover_incident`.
3. Admin: lengkapi `admin-auditor-<nama-tim>.sql` (user `OPS_AUDITOR`, role `OPS_AUDIT` dengan `CREATE SESSION` saja), lalu jalankan di container:

```powershell
docker cp admin-auditor-<nama-tim>.sql oracle-xe:/tmp/admin-auditor.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/admin-auditor.sql
```

4. Pemilik tabel: view `v_incident_audit` (`incident_no`, `status`, `priority`, `assigned_to`, `updated_at`; tanpa `summary`), lalu `GRANT SELECT` hanya di `incident_log` dan `v_incident_audit` kepada `ops_audit`.

## E. Laporan antrean yang lambat

Query dashboard (ada di `perbaikan-tim.sql`) menampilkan tiket `IN_PROGRESS` layanan `service_id = 3` yang dibuka pada September 2026. Catat plan sebelumnya (`EXPLAIN PLAN`). Lalu buat view `v_laporan_antrean` dengan hasil **sama persis** (kolom `incident_no`, `priority`, `assigned_to`, `opened_at`) yang ditulis supaya bisa memakai index, dan buat index composite dengan nama berawalan `idx_lab_`. Catat operation dan cost sesudahnya.

## Cek otomatis

`COMMIT` dulu perbaikan di SQL Developer: cek memakai session lain. Dari folder `lab` (PowerShell dan terminal macOS sama):

```powershell
docker cp cek-lab.sql oracle-xe:/tmp/cek-lab.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/cek-lab.sql
```

Yang harus terlihat: tabel poin per kriteria, `Subtotal otomatis` (maks. 80), dan bagian `Catatan` berisi petunjuk untuk poin yang belum penuh. Cek tidak mengubah data: procedure, function, dan trigger tim diuji di dalam savepoint lalu di-`ROLLBACK`, dan `COMMIT`, `ROLLBACK`, serta DDL dari dalam PL/SQL dikunci (`ALTER SESSION DISABLE COMMIT IN PROCEDURE`), sehingga procedure yang memanggil `COMMIT` langsung ketahuan (`ORA-00034`). Perbaiki, `COMMIT`, lalu jalankan cek lagi.

## Rubrik Lab (100 poin)

| Kriteria | Poin | Dinilai oleh | Indikator keberhasilan |
| --- | --- | --- | --- |
| A. Pemulihan data | 20 | `cek-lab.sql` | `closed_at` tiket 0006 dan 0009 (6), tiket 0017 (3), 0020 (3), 0022 kembali ke pemegang sah (4), 30 tiket asli utuh tanpa pelanggaran aturan (4) |
| B. Serah terima aman | 18 | `cek-lab.sql` | Procedure `VALID` (2), serah terima sah tercatat (6), pemegang salah ditolak tanpa perubahan (5), tiket tidak `IN_PROGRESS` atau tidak ada ditolak (2), `FOR UPDATE` tanpa `COMMIT`/`ROLLBACK` (3) |
| C. Penjaga data | 12 | `cek-lab.sql` | `active_incident_count` benar untuk 6 kode (5), tiket `CLOSED` tidak bisa dibuka (5), perubahan sah tetap jalan (2) |
| D. Hak akses | 16 | `cek-lab.sql` | Tanpa DML langsung operator (4), operator tetap `SELECT` + `EXECUTE` handover (3), readonly tanpa `incident` dan log (2), user dan role auditor (3), auditor hanya dua hak baca (3), hak sistem hanya `CREATE SESSION` (1) |
| E. Laporan antrean | 14 | `cek-lab.sql` | Hasil view sama (4), plan memakai index `idx_lab_` tanpa full scan (6), cost plan paling tinggi 150 (4) |
| Laporan insiden | 10 | Review tim lain | Akar masalah, perintah inti, dan bukti sebelum/sesudah tiap temuan, termasuk letak `SAVEPOINT` dan `COMMIT` |
| Uji dua session | 6 | Review tim lain | Session B menunggu, lalu ditolak setelah A `COMMIT`; satu kalimat alasan |
| Lab bisa diulang | 4 | Review tim lain | `00-insiden.sql` lalu `perbaikan-<nama-tim>.sql` dijalankan lagi dari awal tanpa error |
| **Total** | **100** | | |

Target minimal 60 poin. Cek sendiri dengan `cek-lab.sql` dan rubrik di atas.

Akun `OPS_AUDITOR` bisa diuji dengan koneksi baru: `SELECT` dari `ops_lab.incident_log` dan `ops_lab.v_incident_audit` berhasil, `SELECT` dari `ops_lab.incident` ditolak `ORA-00942`, `UPDATE ops_lab.v_incident_audit` ditolak `ORA-01031`.

## Bonus Lab (opsional, maks. +10)

1. (+5) Covering index `idx_lab_cover` untuk laporan antrean, sehingga `EXPLAIN PLAN` dari `v_laporan_antrean` hanya `INDEX RANGE SCAN` tanpa `TABLE ACCESS`. Catat cost sebelum dan sesudahnya, lalu hapus index ini setelah dicatat.
2. (+5) Procedure `claim_next_incident(p_operator, p_incident_no OUT)` yang mengambil tiket `OPEN` asli (bukan data bulk) terdepan menurut prioritas lalu waktu buka, memakai cursor `FOR UPDATE SKIP LOCKED`, tanpa `COMMIT`. Uji dua session: keduanya mendapat tiket berbeda tanpa saling tunggu. Akhiri dengan `ROLLBACK`.

Bonus dinilai lewat review.
