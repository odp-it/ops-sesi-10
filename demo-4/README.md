> Buka folder ini untuk bagian ini. Semua path relatif terhadap folder ini. Persiapan, troubleshooting, dan cleanup: [README utama](../README.md).

# Demo 4 · Index dan Execution Plan (±30 menit)

Instruktur memperagakan data besar, membaca execution plan sebelum dan sesudah index composite, dan tiga pola yang membuat index tidak dipakai (±12 menit). Peserta mengerjakan 4.1–4.11 (±18 menit). Data bulk dari 4.2 dan index dari 4.6 dipakai lagi di Lab: **jangan jalankan 4.12 sebelum Lab selesai**.

## 4.1 Izin statistik plan (admin, ±2 menit)

```powershell
docker cp setup/04-grant-plan-stats.sql oracle-xe:/tmp/04-grant-plan-stats.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/04-grant-plan-stats.sql
```

Yang harus terlihat: empat `Grant succeeded.` lalu `Izin statistik plan untuk OPS_LAB selesai.` Tanpa 4.1, 4.5 dan 4.8 gagal, tetapi plan di 4.4 dan 4.7 tetap terbaca.

## 4.2 Data besar (±3 menit)

Buka `05-bulk-incident.sql`, koneksi `OPS_LAB @ XEPDB1`, tekan **F5** (±10 detik). Yang harus terlihat: `JUMLAH_INCIDENT 200030`; status `CLOSED 180010`, `IN_PROGRESS 5009`, `OPEN 3004`, `RESOLVED 12007` (angka `IN_PROGRESS` dan `OPEN` ikut berubah kalau Demo 1–3 dikerjakan sebagian).

## 4.3–4.5 Plan sebelum index (±5 menit)

Buka `05-index-plan.sql`. Jalankan 4.3 (hanya `PK_INCIDENT` dan `UQ_INCIDENT_NO`), 4.4 (`EXPLAIN PLAN` lalu `DBMS_XPLAN.DISPLAY`), dan 4.5 (query dengan `GATHER_PLAN_STATISTICS`, lalu `DISPLAY_CURSOR`).

Yang harus terlihat: `TABLE ACCESS FULL` pada `INCIDENT`, cost `788`, `E-Rows 46`, `A-Rows 35`, `Buffers 2895`. Catat operation, cost, dan Buffers.

## 4.6–4.8 Index dan plan sesudahnya (±5 menit)

Jalankan 4.6 (`CREATE INDEX idx_incident_status_prio_opened ON incident (status, priority, opened_at)`), 4.7, dan 4.8. Yang harus terlihat: `Index created.`, `INDEX RANGE SCAN` pada `IDX_INCIDENT_STATUS_PRIO_OPENED` dengan `TABLE ACCESS BY INDEX ROWID`, cost `50`, `Buffers 25`, dan tanpa `SORT ORDER BY`. Catat angka sesudah.

Angka Buffers di atas dari SQL Developer for VS Code (diverifikasi ulang di XE 21.3.0: SQL*Plus dengan `ARRAYSIZE 200` juga `25`; SQL*Plus bawaan `ARRAYSIZE 15` menampilkan `28` karena baris diambil bertahap). Angka cost dan Buffers bisa beda tipis di laptop lain; jenis operation dan selisih besar harus sama.

## 4.9–4.11 Pola yang membuat index tidak dipakai (±3 menit)

Jalankan 4.9, 4.10, 4.11. Yang harus terlihat: ketiganya `TABLE ACCESS FULL`. Tulis satu kalimat alasan per pola: 4.9 kolom pertama index tidak disebut, 4.10 fungsi `UPPER` membungkus kolom, 4.11 `CLOSED` mewakili ±90% baris sehingga membaca seluruh tabel lebih murah.

## 4.12 Bersihkan (opsional, setelah Lab)

Buka `05b-hapus-bulk.sql`, koneksi `OPS_LAB @ XEPDB1`, **F5**: data uji dan index terhapus, `JUMLAH_INCIDENT 30`.

## Tantangan tambahan Demo 4 (opsional)

**T4.1 Covering index (±8 menit).** Query `SELECT incident_no, opened_at FROM incident WHERE status = 'OPEN' AND priority = 'P1' AND opened_at >= TIMESTAMP '2026-06-01 00:00:00'` masih membaca tabel lewat `TABLE ACCESS BY INDEX ROWID` untuk mengambil `incident_no`. Buat `idx_incident_cover ON incident (status, priority, opened_at, incident_no)`, jalankan `EXPLAIN PLAN` dan `DBMS_XPLAN.DISPLAY` sebelum dan sesudahnya. Yang harus terlihat: sebelum: `TABLE ACCESS BY INDEX ROWID BATCHED` (cost `50`) di atas `INDEX RANGE SCAN` pada `IDX_INCIDENT_STATUS_PRIO_OPENED` (cost `3`); sesudah: hanya `INDEX RANGE SCAN` pada `IDX_INCIDENT_COVER` (cost `3`), tanpa `TABLE ACCESS`. Catat: semua kolom yang dibutuhkan ada di index, jadi tabel tidak dibaca; harga yang dibayar adalah index lebih besar dan `INSERT` lebih lambat.

**T4.2 Index INVISIBLE (±5 menit).** `ALTER INDEX idx_incident_cover INVISIBLE;` dan `ALTER INDEX idx_incident_status_prio_opened INVISIBLE;`, ulangi `EXPLAIN PLAN`. Yang harus terlihat: `TABLE ACCESS FULL`, cost `787`, dan `USER_INDEXES` menampilkan `VISIBILITY` `INVISIBLE`. Kembalikan dengan `ALTER INDEX ... VISIBLE;` untuk kedua index, lalu `DROP INDEX idx_incident_cover;`. Index `INVISIBLE` tetap dipelihara tetapi tidak dipakai optimizer: cara aman menguji apakah index boleh dihapus.
