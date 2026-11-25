-- Sesi 10 · Demo 4: Data bulk untuk latihan indexing
-- Menambah 200.000 incident uji (INC-SIM-B000001 s.d. INC-SIM-B200000), Januari-Oktober 2026.
-- Data dibangkitkan dengan rumus (bukan acak), jadi hasilnya sama di semua laptop. Sebagian besar CLOSED,
-- hanya ±1,5% OPEN: mirip kondisi nyata, dan alasan index pada status + priority berguna.
-- Jalankan sebagai OPS_LAB dengan Run Script (F5). Incident asli (INC-SIM-0001 s.d. INC-SIM-0030) tidak diubah.
-- Trigger trg_incident_audit hanya aktif untuk UPDATE, jadi tidak menulis log untuk INSERT massal ini.

INSERT INTO incident (incident_id, incident_no, service_id, asset_id, category, priority, status, assigned_to,
                      summary, opened_at, closed_at, updated_at)
SELECT seq_incident.NEXTVAL,
       'INC-SIM-B' || LPAD(g.n, 6, '0'),
       MOD(g.n, 5) + 1,
       MOD(g.n, 10) + 1,
       CASE MOD(g.n, 5) WHEN 0 THEN 'JARINGAN' WHEN 1 THEN 'APLIKASI' WHEN 2 THEN 'PERANGKAT'
                        WHEN 3 THEN 'AKSES' ELSE 'DATABASE' END,
       CASE WHEN MOD(TRUNC(g.n / 1000) * 7 + g.n, 97) < 3 THEN 'P1' WHEN MOD(TRUNC(g.n / 1000) * 7 + g.n, 97) < 15 THEN 'P2'
            WHEN MOD(TRUNC(g.n / 1000) * 7 + g.n, 97) < 60 THEN 'P3' ELSE 'P4' END,
       CASE WHEN MOD(g.n, 1000) < 900 THEN 'CLOSED' WHEN MOD(g.n, 1000) < 960 THEN 'RESOLVED'
            WHEN MOD(g.n, 1000) < 985 THEN 'IN_PROGRESS' ELSE 'OPEN' END,
       CASE WHEN MOD(g.n, 1000) >= 985 THEN NULL ELSE 'op.uji' END,
       'Data uji massal ' || g.n,
       TIMESTAMP '2026-01-01 08:00:00' + NUMTODSINTERVAL(MOD(g.n * 7919, 300 * 24 * 60), 'MINUTE'),
       CASE WHEN MOD(g.n, 1000) < 960
            THEN TIMESTAMP '2026-01-01 10:00:00' + NUMTODSINTERVAL(MOD(g.n * 7919, 300 * 24 * 60), 'MINUTE') END,
       TIMESTAMP '2026-01-01 08:00:00' + NUMTODSINTERVAL(MOD(g.n * 7919, 300 * 24 * 60), 'MINUTE')
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 200000) g;

COMMIT;

-- Perbarui statistik tabel (dengan histogram) supaya optimizer tahu ukuran dan sebaran status dan priority yang baru
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'INCIDENT', method_opt => 'FOR ALL COLUMNS SIZE 254');
END;
/

SELECT COUNT(*) AS jumlah_incident FROM incident;
SELECT status, COUNT(*) AS jumlah FROM incident GROUP BY status ORDER BY status;
