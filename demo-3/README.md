> Buka folder ini untuk bagian ini. Semua path relatif terhadap folder ini. Persiapan, troubleshooting, dan cleanup: [README utama](../README.md).

# Demo 3 · User, Role, Privilege (±30 menit)

Instruktur memperagakan skrip admin, `GRANT` ke role lewat view dan procedure, uji dari dua user, dan `REVOKE` (±10 menit, sebelum coffee break). Peserta mengerjakan 3.1–3.4 (±20 menit, sesudah coffee break).

Skenario: operator tidak boleh login sebagai pemilik tabel (`OPS_LAB`). Dibuat `OPS_AGENT` (role `OPS_OPERATOR`: membaca dan mengubah incident hanya lewat procedure) dan `OPS_VIEWER` (role `OPS_READONLY`: membaca incident aktif lewat view). Password di langkah ini **password latihan lokal** yang kamu karang sendiri, bukan password asli.

## 3.1 Admin membuat user dan role (±4 menit)

```powershell
docker cp setup/01-admin-roles.sql oracle-xe:/tmp/01-admin-roles.sql
docker exec -it oracle-xe sqlplus / as sysdba @/tmp/01-admin-roles.sql
```

Ketik password latihan untuk `OPS_VIEWER` dan `OPS_AGENT` saat diminta. Yang harus terlihat: `PL/SQL procedure successfully completed.`, empat `Grant succeeded.`, dua baris `OPEN`, dan empat pasangan user-role (`OPS_AGENT` ke `OPS_OPERATOR`, `OPS_VIEWER` ke `OPS_READONLY`).

## 3.2 Pemilik tabel memberi izin (±3 menit)

Buka `04-privilege-owner.sql`, pasang koneksi `OPS_LAB @ XEPDB1`, tekan **F5**. Yang harus terlihat: `View created.`, delapan `Grant succeeded.`, lalu 8 baris di `USER_TAB_PRIVS_MADE`: `OPS_OPERATOR` mendapat `SELECT` di tiga objek dan `EXECUTE` di dua procedure, `OPS_READONLY` mendapat `SELECT` di tiga objek (`ASSET`, `SERVICE`, `V_INCIDENT_AKTIF`).

## 3.3 Uji dari dua session lain (±9 menit)

1. Buat dua koneksi baru seperti P3: `OPS_AGENT @ XEPDB1` (user `OPS_AGENT`) dan `OPS_VIEWER @ XEPDB1` (user `OPS_VIEWER`), service name `XEPDB1`, password dari 3.1.
2. Buka `04-privilege-uji-agent.sql`, pasang koneksi `OPS_AGENT @ XEPDB1`. Jalankan satu perintah sekali jalan:

| Langkah | Perintah | Yang harus terlihat |
| --- | --- | --- |
| 3.3.1 | `SELECT` status dari `ops_lab.incident` | berhasil, tabel status tampil |
| 3.3.2 | `EXEC ops_lab.assign_incident(...)` | `PL/SQL procedure successfully completed.`, `INC-SIM-0003` `IN_PROGRESS` untuk `op.sari` |
| 3.3.3 | `UPDATE ops_lab.incident` langsung | `ORA-01031: insufficient privileges` |
| 3.3.4 | `SELECT` dari `ops_lab.incident_log` | `ORA-00942: table or view does not exist` |
| 3.3.5 | `CREATE TABLE catatan_agent` | `ORA-01031: insufficient privileges` |
| 3.3.6 | `session_roles` dan `role_tab_privs` | `OPS_OPERATOR`; lima hak (`SELECT` tiga objek, `EXECUTE` dua procedure) |

3. Buka `04-privilege-uji-viewer.sql`, pasang koneksi `OPS_VIEWER @ XEPDB1`:

| Langkah | Perintah | Yang harus terlihat |
| --- | --- | --- |
| 3.3.7 | `SELECT` dari `ops_lab.v_incident_aktif` dan `ops_lab.service` | berhasil |
| 3.3.8 | `SELECT` dari `ops_lab.incident` | `ORA-00942: table or view does not exist` |
| 3.3.9 | `EXEC ops_lab.assign_incident(...)` | `PLS-00201: identifier 'OPS_LAB.ASSIGN_INCIDENT' must be declared` |

`ORA-01031` muncul bila user punya hak lain pada objek itu tetapi tidak punya hak yang diminta; `ORA-00942` muncul bila user sama sekali tidak punya hak, sehingga objeknya seolah tidak ada.

## 3.4 Cabut izin dan uji ulang (±4 menit)

1. Buka `04-privilege-revoke.sql`, koneksi `OPS_LAB @ XEPDB1`, jalankan 3.4.1 (`Revoke succeeded.`) dan 3.4.2 (hak `EXECUTE` tinggal `ASSIGN_INCIDENT`).
2. Kembali ke tab `OPS_AGENT`, jalankan 3.4.3 (`EXEC ops_lab.escalate_incident(...)`). Yang harus terlihat: `PLS-00201: identifier 'OPS_LAB.ESCALATE_INCIDENT' must be declared`.

## Tantangan tambahan Demo 3 (opsional)

**T3.1 View dengan target SLA (±7 menit).** Sebagai `OPS_LAB`, buat view `v_incident_sla` berisi `incident_no`, `priority`, `status`, dan `target_jam` (dari `sla_target_hours(priority)`), hanya untuk incident `OPEN` dan `IN_PROGRESS`, lalu `GRANT SELECT` ke role `ops_readonly`. Uji dari `OPS_VIEWER`: `SELECT priority, COUNT(*) AS jumlah, MAX(target_jam) AS target_jam FROM ops_lab.v_incident_sla GROUP BY priority ORDER BY priority`. Yang harus terlihat: 4 baris (13 incident aktif): `P1 1 2`, `P2 5 4`, `P3 3 8`, `P4 4 24`. Lalu `SELECT assigned_to FROM ops_lab.v_incident_sla` ditolak `ORA-00904: "ASSIGNED_TO": invalid identifier` (kolom itu tidak ada di view). Catat: `OPS_VIEWER` tidak punya hak `EXECUTE` pada function, tetapi view tetap jalan karena memakai hak pemilik view.

**T3.2 Kunci dan buka akun (±5 menit).** Di terminal admin: `docker exec -it oracle-xe sqlplus / as sysdba`, lalu `ALTER SESSION SET CONTAINER = XEPDB1;` dan `ALTER USER ops_agent ACCOUNT LOCK;`. Buat koneksi baru sebagai `OPS_AGENT` (atau pasang ulang koneksi `OPS_AGENT @ XEPDB1`): `ORA-28000: The account is locked.`. Buka lagi dengan `ALTER USER ops_agent ACCOUNT UNLOCK;`, lalu koneksi berhasil. Keluar dari `sqlplus` dengan `EXIT`.
