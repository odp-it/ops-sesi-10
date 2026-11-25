# Laporan Insiden · Tim <nama-tim>

Salin file ini menjadi `laporan-insiden-<nama-tim>.md`. Singkat: kalimat pendek dan bukti nyata dari layar (angka, nomor error). Dinilai manual (rubrik Lab).

## 1. Temuan dan perbaikan

| Temuan | Akar masalah | Perbaikan (perintah inti) | Bukti sebelum → sesudah |
| --- | --- | --- | --- |
| Data tidak konsisten | | | |
| Tiket tertimpa (lost update) | | | |
| Hak akses berlebih | | | |
| Laporan lambat | | | cost ... → ... |

Transaksi pemulihan: di mana `SAVEPOINT` dan `COMMIT` dijalankan, dan apa yang dilakukan kalau cek gagal:

## 2. Uji dua session untuk handover_incident

| Langkah | Session | Perintah | Yang terlihat |
| --- | --- | --- | --- |
| 1 | A | | |
| 2 | B | | |
| 3 | A | | |
| 4 | B | | |

Kesimpulan satu kalimat: kenapa session B tidak bisa menimpa serah terima session A.

## 3. Pencegahan

Satu usulan supaya insiden yang sama tidak terulang:
