-- The shape the planner should leave: kitchen and hall under corridor,
-- bedroom on the controller. kitchen's legs under corridor and the signals
-- are the A/B of 2026-09-27 morning (AB-KITCHEN-HALL-VS-CORRIDOR):
-- 5 GHz -51 dBm 432/309, 6 GHz -78 dBm 36/51; under hall 5 GHz -45,
-- 6 GHz -69. hall's legs under corridor are assumed (a), card B.
UPDATE bstamld SET ap_mld_macaddr = '02:00:00:00:01:02' WHERE agent_almac IN ('02:00:00:00:00:03', '02:00:00:00:00:04');
INSERT OR REPLACE INTO bsta_link (agent_almac, link_id, band, bssid, state, last_seen, rssi, tx_mbit, rx_mbit) VALUES
	('02:00:00:00:00:02', 0, 2, '02:00:00:00:01:01', 'up', @NOW@ - 20, -52,  864,  720),  -- (a)
	('02:00:00:00:00:02', 1, 8, '02:00:00:00:06:01', 'up', @NOW@ - 20, -71,  576,  432),  -- (a)
	('02:00:00:00:00:03', 0, 2, '02:00:00:00:01:02', 'up', @NOW@ - 20, -42,  720,  720),  -- (a)
	('02:00:00:00:00:03', 1, 8, '02:00:00:00:06:02', 'up', @NOW@ - 20, -62, 1153, 1153),  -- (a)
	('02:00:00:00:00:04', 0, 2, '02:00:00:00:01:02', 'up', @NOW@ - 20, -51,  432,  309),
	('02:00:00:00:00:04', 1, 8, '02:00:00:00:06:02', 'up', @NOW@ - 20, -78,   36,   51),
	('02:00:00:00:00:05', 0, 2, '02:00:00:00:01:01', 'up', @NOW@ - 20, -55,  648,  576),  -- (a)
	('02:00:00:00:00:05', 1, 8, '02:00:00:00:06:01', 'up', @NOW@ - 20, -72,  144,  144);
INSERT OR REPLACE INTO bh_candidate (agent_almac, bssid, freq, signal, scan_ts) VALUES
	('02:00:00:00:00:04', '02:00:00:00:01:02', 5180, -51, @NOW@ - 120),
	('02:00:00:00:00:04', '02:00:00:00:06:02', 6135, -78, @NOW@ - 120),
	('02:00:00:00:00:04', '02:00:00:00:01:03', 5180, -45, @NOW@ - 120),
	('02:00:00:00:00:04', '02:00:00:00:06:03', 6135, -69, @NOW@ - 120);
