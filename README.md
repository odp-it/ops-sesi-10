# 10 - Transactions, Concurrency & Database Administration

Lab ini memakai data operasional IT dari sesi 7–9: tabel `asset`, `service`, dan `incident` di Oracle XE. Hasil akhirnya: transaksi yang di-commit dan di-rollback dengan bukti dari dua session, row lock, lost update, dan deadlock yang diamati langsung, function, procedure, dan trigger yang mengotomasi pencatatan incident, user dan role dengan hak minimum, bukti before/after index dari execution plan, serta pemulihan satu insiden operasional di Lab yang dinilai dengan rubrik 100 poin.

## Tujuan

1. Menjalankan perubahan incident sebagai satu transaksi dengan `COMMIT`, `ROLLBACK`, dan `SAVEPOINT`, dan menjelaskan prinsip ACID dari hasilnya.
2. Mengamati row lock, lost update, `SELECT ... FOR UPDATE`, dan deadlock `ORA-00060` dari dua session, lalu melihat session yang saling mengunci sebagai admin.
3. Membuat function, procedure, dan trigger untuk otomasi proses incident, dan membaca error compile.
4. Membuat user dan role dengan hak minimum (least privilege), menguji `ORA-01031` dan `ORA-00942`, dan mencabut izin dengan `REVOKE`.
5. Membaca execution plan sebelum dan sesudah index composite pada tabel incident yang besar.

## Estimasi Waktu

Format sesi: **4 Demo + 1 Lab**. Di tiap Demo instruktur memperagakan dulu, lalu peserta mengikuti langkah bernomor dari file di folder ini. Demo 1 dan 2 inti sesi (transaksi, locking, program database): wajib selesai. Demo 3 dan 4 penting. **Lab** adalah tugas tim yang memperbaiki satu insiden operasional memakai semua yang dipraktikkan di Demo, dinilai dengan rubrik 100 poin dan cek otomatis. Tiap Demo punya **Tantangan tambahan** untuk yang selesai lebih cepat (tidak wajib).

| Bagian | Durasi di kelas (peraga + ikuti) |
| --- | --- |
| Pembuka · cek container dan catch-up | ±10 menit |
| Demo 1 · Transaksi (1.1–1.5) dan Locking (1.6–1.12) | ±65 menit (20 + 45) |
| Demo 2 · Function, procedure, trigger | ±35 menit (14 + 21) |
| Demo 3 · User, role, privilege | ±30 menit (10 + 20) |
| Demo 4 · Index dan execution plan | ±30 menit (12 + 18) |
| **Lab** · Pemulihan insiden operasi (lanjut setelah kelas) | ±35 menit |
| Penutup | ±5 menit |
| **Total** | **210 menit** |

Tantangan tambahan di akhir tiap Demo dan Bonus Lab bersifat opsional; tidak masuk hitungan di atas.

## Environment & Tools

Disiapkan sebelum kelas. Versi dikunci: jangan update tool selama kelas.

| Item | Versi | Cara cek | Harus terlihat |
| --- | --- | --- | --- |
| Container Oracle | Oracle Database 21c Express Edition 21.3.0 (`container-registry.oracle.com/database/express:21.3.0-xe`) | `docker ps` | `oracle-xe` dengan status `(healthy)` |
| Pluggable database | `XEPDB1` | Koneksi di bawah | Layanan `XEPDB1` |
| VS Code + Oracle SQL Developer for VS Code | 26.3.1 | Panel SQL Developer | Koneksi `OPS_LAB @ XEPDB1` |
| Docker Desktop (atau Rancher Desktop) | Versi terpasang di laptop | `docker --version` | Versi tampil |

Versi dicek 24 Nov 2026 (Oracle Container Registry, Marketplace VS Code). Oracle XE 21c tidak punya fitur 23ai (tanpa tipe `BOOLEAN` di SQL, tanpa `CREATE ... IF NOT EXISTS`), jadi seluruh perintah di lab ini sudah disesuaikan.

### Container Oracle XE

Kalau container dari sesi 7 masih ada (`docker ps -a` menampilkan `oracle-xe`), jalankan `docker start oracle-xe` dan lewati langkah ini. Kalau belum ada, buat satu kali (unduhan ±3,75 GB, pertama kali start ±3 menit sampai `DATABASE IS READY TO USE!` di `docker logs oracle-xe`).

Windows (PowerShell):

```powershell
$env:ORACLE_PWD = Read-Host -MaskInput "Password admin Oracle (latihan)"
docker run -d --name oracle-xe -p 1521:1521 -e ORACLE_PWD -v oracle-xe-data:/opt/oracle/oradata container-registry.oracle.com/database/express:21.3.0-xe
```

macOS / Linux (zsh):

```bash
read -s "ORACLE_PWD?Password admin Oracle (latihan): " && export ORACLE_PWD; echo
docker run -d --name oracle-xe -p 1521:1521 -e ORACLE_PWD -v oracle-xe-data:/opt/oracle/oradata container-registry.oracle.com/database/express:21.3.0-xe
```

Kalau container sesi 7 bernama lain, ganti `oracle-xe` di semua perintah `docker` di lab ini. Password admin latihan bukan password asli: karang sendiri.

## Struktur Repo

| Folder | Isi |
| --- | --- |
| [`demo-1/`](demo-1/) | Demo 1 · Transaksi dan Locking |
| [`demo-2/`](demo-2/) | Demo 2 · Function, Procedure, Trigger |
| [`demo-3/`](demo-3/) | Demo 3 · User, Role, Privilege |
| [`demo-4/`](demo-4/) | Demo 4 · Index dan Execution Plan |
| [`lab/`](lab/) | Lab · Pemulihan Insiden Operasi |

Setiap folder punya `README.md` berisi langkahnya. Kerjakan berurutan: `demo-1` sampai `demo-4`, lalu `lab`.

## Demo dan Lab

Demo 1–4 dikerjakan **berpasangan**: satu orang mengetik, satu orang mencatat dan mencocokkan hasil, lalu bertukar peran setiap Demo. Locking (Demo 1) membutuhkan dua session sekaligus. Lab dikerjakan **per tim** di satu laptop.

### Target

| Bagian | Hasil |
| --- | --- |
| Demo 1 · Transaksi (1.1–1.5) | Catatan: status incident sebelum dan sesudah `ROLLBACK` dan `COMMIT`, serta satu error yang tidak membatalkan statement sebelumnya |
| Demo 1 · Locking (1.6–1.12) | Catatan: lama session B menunggu, lost update dan cara mencegahnya, `ORA-00054`, `ORA-30006`, `ORA-00060`, `ORA-08177`, dan hasil query admin |
| Demo 2 | Lima objek (2 function, 2 procedure, 1 trigger) berstatus `VALID`, dan log otomatis tercatat |
| Demo 3 | Tabel catatan: perintah apa yang boleh dan ditolak untuk `OPS_AGENT` dan `OPS_VIEWER`, beserta nomor error |
| Demo 4 | Tabel catatan before/after: operation, cost, Buffers |
| Lab | Insiden diperbaiki, skor otomatis dari `lab/cek-lab.sql`, dan laporan insiden tim |

### Studi Kasus

Tim IT operations sebuah bank fiktif menangani tiket gangguan (incident) atas aset dan layanan internal. Dua operator sering membuka tiket yang sama, status tiket harus tercatat riwayatnya, operator tidak boleh mengubah data sembarangan, dan daftar tiket terbuka harus tetap cepat ketika jumlah tiket membesar menjadi ratusan ribu. Semua nama, kode, dan data di lab ini fiktif (`AST-SIM-`, `SVC-SIM-`, `INC-SIM-`).

### Persiapan · Cek Container dan Catch-up (±10 menit)

#### P1. Cek container

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

Yang harus terlihat: `oracle-xe` dengan status `(healthy)` dan port `1521`.

#### P2. Buat user OPS_LAB (admin)

Pembuatan user adalah tugas admin (DBA), jadi dijalankan sebagai SYSDBA di dalam container. Dari folder utama repo:

```powershell
docker cp demo-1/setup/00-admin-user.sql oracle-xe:/tmp/00-admin-user.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/00-admin-user.sql
```

Ketik password latihan untuk `OPS_LAB` saat diminta (tidak tampil di layar). Yang harus terlihat: `Grant succeeded.`, satu baris `OPS_LAB` berstatus `OPEN` dengan tablespace `USERS`, lalu `Langkah admin 1 selesai.`

#### P3. Buat koneksi OPS_LAB

Di panel Oracle SQL Developer, **Create Connection**: **Connection Name** `OPS_LAB @ XEPDB1`, **Username** `OPS_LAB`, **Password** dari P2, **Hostname** `localhost`, **Port** `1521`, **Service Name** `XEPDB1`. Klik **Test**: `Test passed`. Auto Commit **tidak** dicentang.

#### P4. Catch-up

Kalau tabel `asset`, `service`, dan `incident` dari sesi 7–9 sudah ada dan nama tabel serta kolomnya sama, lewati P4 dan cek `SELECT COUNT(*) FROM incident;` (harus `30`). Kalau belum atau beda, buka `demo-1/catchup/00-catchup-sesi-7-9.sql`, pasang koneksi `OPS_LAB @ XEPDB1`, tekan **F5** (Run Script). Skrip ini menghapus lalu membuat ulang empat tabel dan dua sequence di schema `OPS_LAB`, jadi aman diulang kapan saja untuk mengembalikan data awal.

Yang harus terlihat: `JUMLAH_ASSET 10`, `JUMLAH_SERVICE 5`, `JUMLAH_INCIDENT 30`, `JUMLAH_LOG 0`.

Cara menjalankan SQL: pasang koneksi lewat status bar, **Run Statement** `Ctrl+Enter` (Windows/Linux) atau `⌘Enter` (macOS) untuk satu perintah, **Run Script** `F5` untuk satu file atau blok yang diseleksi, **Explain Plan** `F10`. Auto Commit mati.

## Checklist

- [ ] Demo 1 · A: `ROLLBACK` mengembalikan status dan log; error `ORA-02290` tidak membatalkan `UPDATE` sebelumnya; DDL meng-commit otomatis
- [ ] Demo 1 · B: session B menunggu di 1.7, lost update terlihat di 1.8 dan `0 rows updated.` di 1.8.8, `ORA-00054`/`ORA-30006` di 1.9, `ORA-00060` di 1.10, `ORA-08177` di 1.11, query admin tampil di 1.12
- [ ] Demo 2: 2 function, 2 procedure, 1 trigger `VALID`; `ORA-04098` terlihat saat trigger `INVALID`; log otomatis tercatat
- [ ] Demo 3: `OPS_AGENT` bisa `EXEC` tetapi `UPDATE` ditolak (`ORA-01031`); `OPS_VIEWER` ditolak (`ORA-00942`, `PLS-00201`); `REVOKE` berlaku
- [ ] Demo 4: tabel before/after terisi (`TABLE ACCESS FULL` jadi `INDEX RANGE SCAN`) dan tiga pola index tidak dipakai dijelaskan
- [ ] Lab: `lab/cek-lab.sql` menampilkan skor otomatis (target minimal 48 dari 80, setara 60%) dan laporan insiden terisi

## Troubleshooting

| Gejala | Kemungkinan penyebab | Solusi |
| --- | --- | --- |
| `docker: Error response ... port is already allocated` | Port `1521` dipakai container atau Oracle lain | Hentikan yang lain (`docker ps`), atau pakai `-p 1522:1521` dan ganti port di koneksi |
| `ORA-12541: TNS:no listener` atau `ORA-12514` di koneksi | Container belum siap, atau service name salah | Tunggu `DATABASE IS READY TO USE!` di `docker logs oracle-xe`; pakai service `XEPDB1` (bukan `XE`) |
| `ORA-01017: invalid credential or not authorized; logon denied` | Password beda dari yang diketik di langkah admin | Jalankan ulang skrip admin dengan password baru (aman diulang), perbarui password koneksi |
| `ORA-01045: user ... lacks CREATE SESSION privilege` | Skrip admin belum selesai | Jalankan ulang `demo-1/setup/00-admin-user.sql` atau `demo-3/setup/01-admin-roles.sql` |
| Run Statement di session B terus berputar | Session B menunggu lock session A (1.7.3, 1.12.2 berjalan seperti yang diharapkan) | Jalankan `COMMIT` atau `ROLLBACK` di session A; session B lanjut sendiri |
| Session A dan B sama-sama berhenti setelah salah langkah | Ada transaksi menggantung di salah satu tab | `ROLLBACK;` di kedua tab, ulangi dari 1.7.1 |
| `lab/00-insiden.sql`: `ORA-20900: Role OPS_OPERATOR / OPS_READONLY belum ada` | Skrip admin 3.1 belum dijalankan | Jalankan `demo-3/setup/01-admin-roles.sql`, lalu ulangi `lab/00-insiden.sql` |
| `lab/cek-lab.sql`: `Insiden belum terpasang` dan semua 0 | `lab/00-insiden.sql` belum dijalankan, atau baris log insiden dihapus | Jalankan `lab/00-insiden.sql`, lalu perbaikan tim |
| `lab/cek-lab.sql`: poin tidak naik setelah diperbaiki | Perbaikan belum di-`COMMIT`, atau transaksi masih terbuka | `COMMIT` di SQL Developer, jalankan cek lagi |
| `lab/cek-lab.sql`: `B dan C2-C3 tidak diuji ... ORA-00054` | Baris uji dikunci transaksi lain | `COMMIT` atau `ROLLBACK` di semua tab, jalankan cek lagi |
| `lab/cek-lab.sql`: `ORA-00034` di catatan B | Procedure memanggil `COMMIT` atau `ROLLBACK` | Hapus `COMMIT`/`ROLLBACK` dari procedure, kompilasi ulang |
| `lab/cek-lab.sql`: `data bulk belum ada` | Data uji 4.2 sudah dihapus (4.12) | Jalankan `demo-4/05-bulk-incident.sql` |
| `ORA-00054` di bagian locking yang bukan `FOR UPDATE NOWAIT` | Transaksi lama masih memegang baris | `ROLLBACK;` di semua tab, atau jalankan ulang `demo-1/catchup/00-catchup-sesi-7-9.sql` |
| Data tidak sama dengan expected setelah salah langkah | Perubahan yang sudah di-`COMMIT` | Jalankan `demo-1/catchup/00-catchup-sesi-7-9.sql` (F5), lalu ulangi bagian itu |
| `ORA-04098: trigger ... is invalid` | Trigger versi salah masih aktif (2.3) | Jalankan versi perbaikan 2.3d |
| `PLS-00201: identifier ... must be declared` di Demo 3 | Procedure belum dibuat, atau hak `EXECUTE` belum diberikan | Ulangi 2.2 (procedure) atau 3.2 (grant) |
| `ORA-01031` saat `GRANT` di 3.2 | Koneksi bukan `OPS_LAB`, atau tabel milik user lain | Pasang koneksi `OPS_LAB @ XEPDB1` |
| 4.5 atau 4.8: `ORA-01403` / `cannot fetch plan` atau `ORA-00942` pada `v$sql` | 4.1 belum dijalankan, atau query diulang dengan cursor lama | Jalankan 4.1; ubah teks komentar `/* incident-sebelum */` menjadi `/* incident-sebelum-2 */` lalu jalankan ulang query dan `DISPLAY_CURSOR` |
| Cost dan Buffers beda dari expected | Statistik tabel belum diperbarui, atau laptop berbeda | Jalankan `BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER, 'INCIDENT'); END;` lalu `/`; selisih besar sebelum dan sesudah index yang dinilai |
| Worksheet menutup dengan dialog Commit atau Rollback | Ada transaksi terbuka | Pilih **Rollback** |

## Cleanup

Tidak ada yang wajib dihapus. Untuk mengembalikan tabel ke data awal: jalankan `demo-1/catchup/00-catchup-sesi-7-9.sql`. Untuk menghapus seluruh objek latihan (user `OPS_LAB`, `OPS_VIEWER`, `OPS_AGENT`, `OPS_AUDITOR`, ketiga role, dan semua tabel), jalankan `lab/setup/99-cleanup.sql` sebagai admin (`docker cp` lalu `docker exec ... sqlplus / as sysdba @...`). Setelah kelas: `docker stop oracle-xe`.
