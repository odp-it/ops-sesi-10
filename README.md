# 10 - Transactions, Concurrency & Database Administration

Lab ini memakai data operasional IT dari sesi 7–9: tabel `asset`, `service`, dan `incident` di Oracle XE. Hasil akhirnya: transaksi yang di-commit dan di-rollback dengan bukti dari dua session, row lock, lost update, dan deadlock yang diamati langsung, function, procedure, dan trigger yang mengotomasi pencatatan incident, user dan role dengan hak minimum, bukti before/after index dari execution plan, serta pemulihan satu insiden operasional di Lab yang dinilai dengan rubrik 100 poin.

## Environment & Tools

Siapkan sebelum mulai. Versi dikunci: jangan update tool di tengah pengerjaan.

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

## Studi Kasus

Tim IT operations sebuah bank fiktif menangani tiket gangguan (incident) atas aset dan layanan internal. Dua operator sering membuka tiket yang sama, status tiket harus tercatat riwayatnya, operator tidak boleh mengubah data sembarangan, dan daftar tiket terbuka harus tetap cepat ketika jumlah tiket membesar menjadi ratusan ribu. Semua nama, kode, dan data di lab ini fiktif (`AST-SIM-`, `SVC-SIM-`, `INC-SIM-`).

## Persiapan · Cek Container dan Catch-up

### P1. Cek container

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

Yang harus terlihat: `oracle-xe` dengan status `(healthy)` dan port `1521`.

### P2. Buat user OPS_LAB (admin)

Pembuatan user adalah tugas admin (DBA), jadi dijalankan sebagai SYSDBA di dalam container. Dari folder utama repo:

```powershell
docker cp demo-1/setup/00-admin-user.sql oracle-xe:/tmp/00-admin-user.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/00-admin-user.sql
```

Ketik password latihan untuk `OPS_LAB` saat diminta (tidak tampil di layar). Yang harus terlihat: `Grant succeeded.`, satu baris `OPS_LAB` berstatus `OPEN` dengan tablespace `USERS`, lalu `Langkah admin 1 selesai.`

### P3. Buat koneksi OPS_LAB

Di panel Oracle SQL Developer, **Create Connection**: **Connection Name** `OPS_LAB @ XEPDB1`, **Username** `OPS_LAB`, **Password** dari P2, **Hostname** `localhost`, **Port** `1521`, **Service Name** `XEPDB1`. Klik **Test**: `Test passed`. Auto Commit **tidak** dicentang.

### P4. Catch-up

Kalau tabel `asset`, `service`, dan `incident` dari sesi 7–9 sudah ada dan nama tabel serta kolomnya sama, lewati P4 dan cek `SELECT COUNT(*) FROM incident;` (harus `30`). Kalau belum atau beda, buka `demo-1/catchup/00-catchup-sesi-7-9.sql`, pasang koneksi `OPS_LAB @ XEPDB1`, tekan **F5** (Run Script). Skrip ini menghapus lalu membuat ulang empat tabel dan dua sequence di schema `OPS_LAB`, jadi aman diulang kapan saja untuk mengembalikan data awal.

Yang harus terlihat: `JUMLAH_ASSET 10`, `JUMLAH_SERVICE 5`, `JUMLAH_INCIDENT 30`, `JUMLAH_LOG 0`.

Cara menjalankan SQL: pasang koneksi lewat status bar, **Run Statement** `Ctrl+Enter` (Windows/Linux) atau `⌘Enter` (macOS) untuk satu perintah, **Run Script** `F5` untuk satu file atau blok yang diseleksi, **Explain Plan** `F10`. Auto Commit mati.

## Bantuan

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): pesan error dan cara memperbaikinya.
- [CHECKLIST.md](CHECKLIST.md): hasil yang harus terlihat dan kriteria selesai.

## Cleanup

Cleanup bersifat opsional. Untuk mengembalikan tabel ke data awal: jalankan `demo-1/catchup/00-catchup-sesi-7-9.sql`. Untuk menghapus seluruh objek latihan (user `OPS_LAB`, `OPS_VIEWER`, `OPS_AGENT`, `OPS_AUDITOR`, ketiga role, dan semua tabel), jalankan `lab/setup/99-cleanup.sql` sebagai admin (`docker cp` lalu `docker exec ... sqlplus / as sysdba @...`). Setelah selesai: `docker stop oracle-xe`.
