# Checklist

[Kembali ke README](README.md)

## Checklist

- [ ] Demo 1 · A: `ROLLBACK` mengembalikan status dan log; error `ORA-02290` tidak membatalkan `UPDATE` sebelumnya; DDL meng-commit otomatis
- [ ] Demo 1 · B: session B menunggu di 1.7, lost update terlihat di 1.8 dan `0 rows updated.` di 1.8.8, `ORA-00054`/`ORA-30006` di 1.9, `ORA-00060` di 1.10, `ORA-08177` di 1.11, query admin tampil di 1.12
- [ ] Demo 2: 2 function, 2 procedure, 1 trigger `VALID`; `ORA-04098` terlihat saat trigger `INVALID`; log otomatis tercatat
- [ ] Demo 3: `OPS_AGENT` bisa `EXEC` tetapi `UPDATE` ditolak (`ORA-01031`); `OPS_VIEWER` ditolak (`ORA-00942`, `PLS-00201`); `REVOKE` berlaku
- [ ] Demo 4: tabel before/after terisi (`TABLE ACCESS FULL` jadi `INDEX RANGE SCAN`) dan tiga pola index tidak dipakai dijelaskan
- [ ] Lab: `lab/cek-lab.sql` menampilkan skor otomatis (target minimal 48 dari 80, setara 60%) dan laporan insiden terisi
