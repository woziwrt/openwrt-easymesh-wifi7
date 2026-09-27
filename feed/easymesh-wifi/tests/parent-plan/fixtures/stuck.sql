-- 2026-09-27 afternoon: after a power cut everybody hangs on the controller.
-- kitchen at -76/-86 with a 6 Mbit/s backhaul (no MCS rate at all -> 0/0
-- in linkstat), hall at -75 / -84 on 6 GHz. Legs: link 0 = 5 GHz, 1 = 6 GHz.
-- corridor's and bedroom's rates are assumed (a).
INSERT OR REPLACE INTO bsta_link (agent_almac, link_id, band, bssid, state, last_seen, rssi, tx_mbit, rx_mbit) VALUES
	('02:00:00:00:00:02', 0, 2, '02:00:00:00:01:01', 'up',       @NOW@ - 20, -52, 864, 720),  -- (a)
	('02:00:00:00:00:02', 1, 8, '02:00:00:00:06:01', 'up',       @NOW@ - 20, -71, 576, 432),  -- (a)
	('02:00:00:00:00:03', 0, 2, '02:00:00:00:01:01', 'up',       @NOW@ - 20, -75, 144,  72),  -- (a)
	('02:00:00:00:00:03', 1, 8, '02:00:00:00:06:01', 'degraded', @NOW@ - 20, -84,   0,   0),
	('02:00:00:00:00:04', 0, 2, '02:00:00:00:01:01', 'up',       @NOW@ - 20, -76,   0,   0),
	('02:00:00:00:00:04', 1, 8, '02:00:00:00:06:01', 'down',     @NOW@ - 20, -86,   0,   0),
	('02:00:00:00:00:05', 0, 2, '02:00:00:00:01:01', 'up',       @NOW@ - 20, -55, 648, 576),  -- (a)
	('02:00:00:00:00:05', 1, 8, '02:00:00:00:06:01', 'up',       @NOW@ - 20, -72, 144, 144);  -- bedroom 6G MCS0 1SS, 26. 9.
