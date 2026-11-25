> Buka folder ini untuk bagian ini. Semua path relatif terhadap folder ini. Persiapan, troubleshooting, dan cleanup: [README utama](../README.md).

# Demo 2 · Function, Procedure, Trigger (±35 menit)

Instruktur memperagakan dua function, procedure yang mengunci baris, trigger audit, dan cara membaca error compile (±14 menit). Peserta mengerjakan 2.1–2.4 (±21 menit).

Buka `03-program-db.sql`, pasang koneksi `OPS_LAB @ XEPDB1`. Blok `CREATE ... /` dijalankan dengan Run Script (F5) setelah diseleksi; `SELECT` dan `EXEC` dengan Run Statement.

## 2.1 Function (±4 menit)

Seleksi dan jalankan `sla_target_hours` dan `incident_age_hours`: `Function created.` dua kali. Jalankan 2.1b. Yang harus terlihat: 7 incident `OPEN` yang melewati target SLA (acuan waktu 20 Nov 2026 12.00), dari `INC-SIM-0007` (umur 432,1 jam, target 4) sampai `INC-SIM-0003` (25,9 jam, target 4).

## 2.2 Procedure (±6 menit)

1. Seleksi dan jalankan `assign_incident` dan `escalate_incident`: `Procedure created.` dua kali.
2. 2.2b: `EXEC assign_incident('INC-SIM-0001', 'op.sari')`, lalu `SELECT`: `IN_PROGRESS`, `op.sari`.
3. 2.2c: panggilan kedua ditolak `ORA-20001: Incident INC-SIM-0001 berstatus IN_PROGRESS, hanya OPEN yang bisa diambil`; nomor yang tidak ada ditolak `ORA-20002: Incident INC-SIM-9999 tidak ditemukan`.
4. 2.2d: `EXEC escalate_incident(...)`. Yang harus terlihat: `INC-SIM-0001` jadi `P2`, dan log berisi `Eskalasi P3 ke P2`.

Perhatikan: `assign_incident` mengubah status, tetapi tidak ada baris log. Trigger di 2.3 yang mengerjakannya.

## 2.3 Trigger dan error compile (±8 menit)

1. Seleksi dan jalankan trigger versi pertama (ada salah ketik `:NEW.stats`). Yang harus terlihat: `Trigger TRG_INCIDENT_AUDIT compiled` (SQL*Plus menulis `Warning: Trigger created with compilation errors.`) disusul `Errors for TRIGGER TRG_INCIDENT_AUDIT` dengan `3/6 PLS-00049: bad bind variable 'NEW.STATS'`.
2. 2.3b: `SHOW ERRORS TRIGGER trg_incident_audit` (Run Script): `3/6 PLS-00049: bad bind variable 'NEW.STATS'`. Jalankan dua `SELECT`: `USER_ERRORS` berisi pesan yang sama, `USER_OBJECTS` menunjukkan `TRG_INCIDENT_AUDIT` berstatus `INVALID`.
3. 2.3c: `UPDATE` apa pun di tabel `incident` gagal `ORA-04098: trigger 'OPS_LAB.TRG_INCIDENT_AUDIT' is invalid and failed re-validation`. Trigger yang rusak memblokir semua `UPDATE`.
4. 2.3d: seleksi dan jalankan versi perbaikan. Yang harus terlihat: `Trigger created.`, status `VALID`, `ERROR_TERSISA 0`.

## 2.4 Uji trigger (±3 menit)

Jalankan 2.4: `EXEC assign_incident('INC-SIM-0002', 'op.andi')`, `UPDATE` `INC-SIM-0005` jadi `RESOLVED`, `COMMIT`. Yang harus terlihat: `INC-SIM-0005` punya `closed_at` (`ADA`), `INC-SIM-0002` belum (`TIDAK`), dan log punya baris baru bertuliskan `Trigger audit` tanpa satu pun `INSERT` manual.

## Tantangan tambahan Demo 2 (opsional)

**T2.1 Function `sla_status` (±6 menit).** Buat function `sla_status(p_priority, p_opened_at, p_closed_at, p_now)` yang mengembalikan `LEWAT` atau `AMAN` (`VARCHAR2`; SQL di Oracle XE 21c tidak punya tipe `BOOLEAN`), dengan memanggil `incident_age_hours` dan `sla_target_hours`. Pakai di query: jumlah incident `OPEN` dan `IN_PROGRESS` per prioritas dan status SLA dengan acuan waktu `TIMESTAMP '2026-11-19 14:00:00'`. Yang harus terlihat: 5 baris: `P1 AMAN 1`, `P2 AMAN 1`, `P2 LEWAT 4`, `P3 LEWAT 3`, `P4 LEWAT 4`.

**T2.2 Procedure `resolve_incident` (±8 menit).** Buat procedure `resolve_incident(p_incident_no)` yang hanya menerima incident berstatus `IN_PROGRESS`, mengubahnya jadi `RESOLVED`, lalu `COMMIT`; selain itu `RAISE_APPLICATION_ERROR(-20005, ...)`. Trigger dari 2.3 yang mengisi `closed_at` dan log. Uji `EXEC resolve_incident('INC-SIM-0004')`: `INC-SIM-0004` `RESOLVED` dengan `closed_at` terisi; `EXEC resolve_incident('INC-SIM-0003')` ditolak `ORA-20005: Incident INC-SIM-0003 berstatus OPEN, hanya IN_PROGRESS yang bisa diselesaikan`. Kembalikan: `UPDATE incident SET status = 'IN_PROGRESS' WHERE incident_no = 'INC-SIM-0004'; COMMIT;` (trigger mengosongkan `closed_at`).
