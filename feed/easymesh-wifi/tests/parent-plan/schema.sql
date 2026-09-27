-- The columns of mapc.db that easymesh-parent-plan reads, nothing more.
-- Names and meanings as in map-controller 900/950/975 and
-- easymesh-linkstat-collect; every other column is left out.
CREATE TABLE agent (almac TEXT PRIMARY KEY, last_seen INTEGER);
CREATE TABLE apmld (mld_macaddr TEXT PRIMARY KEY, agent_almac TEXT);
CREATE TABLE affiliated_ap (bssid TEXT PRIMARY KEY, mld_macaddr TEXT, link_id INTEGER);
CREATE TABLE bstamld (mld_macaddr TEXT PRIMARY KEY, agent_almac TEXT, ap_mld_macaddr TEXT);
CREATE TABLE topology_link (child_almac TEXT, parent_almac TEXT, iface_mac TEXT, media_type INTEGER,
	PRIMARY KEY (child_almac, parent_almac, iface_mac));
CREATE TABLE bsta_link (agent_almac TEXT NOT NULL, link_id INTEGER NOT NULL, band INTEGER, bssid TEXT,
	state TEXT, beacon_pct INTEGER, rx_bytes INTEGER, tx_bytes INTEGER, tx_failed INTEGER,
	last_seen INTEGER, rssi INTEGER, tx_mbit INTEGER, rx_mbit INTEGER, chain_spread INTEGER,
	PRIMARY KEY (agent_almac, link_id));
CREATE TABLE bh_candidate (agent_almac TEXT NOT NULL, bssid TEXT NOT NULL, freq INTEGER, signal INTEGER,
	parent TEXT, scan_ts INTEGER, PRIMARY KEY (agent_almac, bssid));
