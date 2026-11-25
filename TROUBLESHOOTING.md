# Troubleshooting

[Kembali ke README](README.md)

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
