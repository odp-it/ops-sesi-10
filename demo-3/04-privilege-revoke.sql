-- Sesi 10 · Demo 3: Mencabut izin (OPS_LAB). Koneksi OPS_LAB @ XEPDB1.

-- 3.4.1 Cabut hak eskalasi dari role OPS_OPERATOR
REVOKE EXECUTE ON escalate_incident FROM ops_operator;

-- 3.4.2 Cek: hak EXECUTE tinggal satu
SELECT grantee, table_name, privilege FROM user_tab_privs_made WHERE grantee = 'OPS_OPERATOR' ORDER BY table_name, privilege;
