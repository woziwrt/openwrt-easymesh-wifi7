// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

/* Clients screen: who is connected where, MLO badges, RCPI history.
 * Read-only over the easymesh ubus dictionary. */

var callState = rpc.declare({ object: 'easymesh', method: 'node_state' });
var callClients = rpc.declare({ object: 'easymesh', method: 'clients' });
var callTopology = rpc.declare({ object: 'easymesh', method: 'topology' });
var callHistory = rpc.declare({ object: 'easymesh', method: 'client_history',
	params: [ 'mac', 'limit' ] });

function fmtAge(s) {
	if (s == null) return '—';
	if (s < 60) return _('%d s ago').format(s);
	if (s < 3600) return _('%d min ago').format(Math.round(s / 60));
	if (s < 86400) return _('%d h ago').format(Math.round(s / 3600));
	return _('%d d ago').format(Math.round(s / 86400));
}

function esc(t) {
	return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function badge(txt, color) {
	return E('span', { 'style': 'display:inline-block;border-radius:10px;padding:0 .6em;' +
		'font-size:.8em;font-weight:bold;color:#fff;background:' + color }, txt);
}

/* inline sparkline from history samples (newest first) */
function sparkline(samples) {
	var pts = (samples || []).slice(0, 32).reverse();
	if (pts.length < 2)
		return E('span', { 'style': 'color:#aaa' }, '—');
	var w = 90, h = 18, min = 255, max = 0;
	pts.forEach(function(p) { min = Math.min(min, p.rcpi); max = Math.max(max, p.rcpi); });
	if (max - min < 10) { max += 5; min -= 5; }
	var path = pts.map(function(p, i) {
		var x = i * w / (pts.length - 1);
		var y = h - 2 - (p.rcpi - min) * (h - 4) / (max - min);
		return (i ? 'L' : 'M') + x.toFixed(1) + ',' + y.toFixed(1);
	}).join('');
	var box = E('span');
	box.innerHTML = '<svg width="' + w + '" height="' + h + '" style="vertical-align:middle">' +
		'<path d="' + path + '" fill="none" stroke="#2e8540" stroke-width="1.5"/></svg>';
	return box;
}

function clientName(c, dhcp) {
	return c.hostname || (dhcp || {})[c.macaddr] || (dhcp || {})[c.mld_macaddr] || null;
}

var GONE_OPEN = false;     /* the folded list keeps its state across redraws */
function renderClients(data, topo, hist) {
	var dhcp = data.dhcp_names || {};
	var names = (topo && topo.names) || {};
	var aff = data.affiliated || [];
	var mldsBy = {};
	(data.mlds || []).forEach(function(m) { mldsBy[m.mld_macaddr] = m; });
	/* An MLO client's legs also arrive in `stations`, each under its own
	 * per-link address, and only `affiliated` says whose they are. Without
	 * this map every leg becomes a row of its own and one phone reads as
	 * four devices - measured 2026-08-27: iPhone be:8d:ac:7a:43:97 plus
	 * 72:17:97:16:bd:50, ee:a4:ee:de:9d:53 and 46:50:33:dd:59:72, its own
	 * three links, all labelled `legacy`.
	 * Two guards. A backhaul station lists itself as its own MLD, so the
	 * two addresses must differ before an entry counts as a leg. And the
	 * leg is hidden only when its owner is actually in `mlds` - otherwise
	 * hiding it would remove the client from the table altogether, which
	 * is worse than showing it under an unfamiliar address. */
	var legsBy = {};
	aff.forEach(function(a) {
		if (a.macaddr && a.mld_macaddr &&
		    a.macaddr != a.mld_macaddr && mldsBy[a.mld_macaddr])
			legsBy[a.macaddr] = a.mld_macaddr;
	});

	var rows = [];
	/* MLO clients first (deduped against stations by MLD address) */
	(data.mlds || []).forEach(function(m) {
		if (m.age_s > 86400) return;
		/* Only a leg with its OWN link address counts. affiliated_sta also
		 * holds a self-referencing row (macaddr == mld_macaddr) that is
		 * history, not a link - and a stale one keeps a departed client
		 * looking multi-link for 20 days. Measured 2026-08-27: the one
		 * genuine MLO client had legs on b6:5b:1b and 3a:a9:3c, both 19 s
		 * old; the two impostors had a single self-leg over half an hour
		 * old, one of them a Mac the HAL reports as 802.11n. */
		/* 2026-09-25: legs are written at association and never refreshed
		 * while the client stays, so "fresh within 300 s" turned every MLO
		 * client into legacy five minutes in (an iPhone with three legs of
		 * its own, 4532 s old, while associated). Count the legs of the
		 * LAST association instead: the ones written together, within a
		 * minute of the newest. Liveness is decided below, not here. */
		var mine = aff.filter(function(a) {
			return a.mld_macaddr == m.mld_macaddr &&
			       a.macaddr != a.mld_macaddr;
		});
		var newest = Math.min.apply(null, mine.map(function(a) {
			return a.age_s == null ? 0 : a.age_s; }).concat([99999]));
		var legs = mine.filter(function(a) {
			return a.age_s == null || a.age_s <= newest + 60;
		});
		rows.push({
			mac: m.mld_macaddr, name: clientName({ macaddr: m.mld_macaddr }, dhcp) || m.hostname,
			/* A leg under an address of its own exists only for an MLD
			 * client (a single-link client sitting on an MLD's BSS has only
			 * the self-leg, excluded above). An MLSR phone is MLO too, it
			 * just uses one link at a time. */
			type: legs.length >= 1 ? 'mlo' : 'legacy',
			legs: legs.length,
			/* The node has to come from the same row as the freshness, for the
			 * same reason. Measured 2026-08-27: a Mac actively browsing this
			 * page sat on the BPI-R4 (8 GB) agent with age 0 in sta, while its sta_mld row
			 * still named the controller from 8668 s earlier - so the table drew
			 * the right time beside the wrong box. Trust sta while it is fresh,
			 * fall back to sta_mld when it is not. */
			node: (function(a) { return names[a] || a || '?'; })(
				(m.sta_agent_almac && m.sta_age_s != null && m.sta_age_s < 300)
					? m.sta_agent_almac : m.agent_almac),
			/* a single-link client that merely sits on an MLD's BSS has no
			 * leg of its own; its signal is in its own station row */
			rcpi: legs.length ? legs[0].rcpi
				: ((data.stations || []).filter(function(st) { return st.macaddr == m.mld_macaddr; })[0] || {}).rcpi,
			/* the best link rate among the legs, kbit/s (PHY); a single-link
			 * client has it in its own station row, like its signal */
			rate: legs.length
				? legs.reduce(function(m, a) { return Math.max(m, a.dl_rate || 0); }, 0) || null
				: ((data.stations || []).filter(function(st) { return st.macaddr == m.mld_macaddr; })[0] || {}).dl_rate || null,
			al: (m.sta_agent_almac && m.sta_age_s != null && m.sta_age_s < 300) ? m.sta_agent_almac : m.agent_almac,
			/* Last seen must come from the row that keeps up. sta_mld
			 * freezes while the client works on - measured the same day,
			 * an active Mac at 53 s in sta and 1556 s in sta_mld, which
			 * the table showed as "14 min ago" beside "online". */
			age: Math.min(m.sta_age_s != null ? m.sta_age_s : 99999,
			              m.age_s     != null ? m.age_s     : 99999,
			              m.leg_age_s != null ? m.leg_age_s : 99999),
			/* Liveness needs association AND freshness, taken from the
			 * right row each time.
			 *
			 * Association alone leaves ghosts: nothing clears associated
			 * when a client goes. Measured 2026-08-27 - a phone with a
			 * dead battery still showed "online, 18 min ago" while a
			 * legacy client gone for 20 min had correctly greyed out.
			 *
			 * `m.age_s` is the wrong row to test: sta_mld stops being
			 * refreshed while the client keeps working (a Mac carried
			 * age_s 1 in stations and 63802 in mlds). `sta_age_s` is the
			 * same client's sta row, which does keep up.
			 *
			 * Older servers send neither column; fall back in that order. */
			/* Newest evidence wins, and the flag is not evidence.
			 * Measured 2026-08-27: an active phone had age_s 1 in
			 * mlds and in its legs, 316 s in sta, and associated 0
			 * in both rows, while the radio showed 10 ms of
			 * inactivity. Forty minutes earlier it was the other way
			 * round for a Mac. A client that has really gone stales
			 * everywhere at once. */
			live: Math.min(m.sta_age_s != null ? m.sta_age_s : 99999,
			               m.age_s     != null ? m.age_s     : 99999,
			               m.leg_age_s != null ? m.leg_age_s : 99999) < 300
		});
	});
	(data.stations || []).forEach(function(s) {
		if (s.is_bsta || mldsBy[s.macaddr] || legsBy[s.macaddr]) return;
		if (s.age_s > 86400) return;
		rows.push({
			mac: s.macaddr, name: clientName(s, dhcp),
			/* a single link: its PHY rate as the AP last reported it, kbit/s */
			type: 'legacy', legs: 0, node: names[s.agent_almac] || s.agent_almac || '?', al: s.agent_almac, rate: s.dl_rate || null,
			/* same rule as the MLO branch above - here the client's own
			 * row is the one we already have, so age_s is the right test */
			rcpi: s.rcpi, age: s.age_s,
			live: (s.associated == 1 && (s.age_s == null || s.age_s < 300))
		});
	});
	/* shed-skin rule: an unnamed client that is offline for >1 h is almost
	 * certainly a rotated iOS private MAC of a device we already list */
	rows = rows.filter(function(r) {
		return r.live || r.name || (r.age != null && r.age < 3600);
	});
	rows.sort(function(a, b) { return (b.live - a.live) || (a.age - b.age); });

	/* 2026-09-25: one section per box, in the order of the tree, so the
	 * page answers "who is on which box" at a glance - including boxes with
	 * nobody on them. Signal in dBm (RCPI / 2 - 110), the link rate of the
	 * best leg, and clients that left in the last 24 h folded at the bottom.
	 * Text follows the theme colour. */
	function dbm(rcpi) { return (rcpi != null && rcpi > 0 && rcpi < 220) ? Math.round(rcpi / 2 - 110) + ' dBm' : ''; }
	function line(r) {
		return E('tr', { 'class': 'tr', 'style': r.live ? '' : 'opacity:.6' }, [
			E('td', { 'class': 'td' }, r.name
				? [ E('strong', {}, r.name), E('div', { 'style': 'opacity:.6;font-size:.85em' }, r.mac) ]
				: E('strong', { 'style': 'font-family:monospace' }, r.mac)),
			E('td', { 'class': 'td' }, r.type == 'mlo'
				? badge(_('MLO') + (r.legs ? ' \u00b7 ' + r.legs + ' ' + (r.legs == 1 ? _('link') : _('links')) : ''), '#7b3fb5')
				: badge(_('single link'), '#8a929c')),
			E('td', { 'class': 'td' }, [ sparkline(hist[r.mac]),
				E('span', { 'style': 'margin-left:.4em' }, dbm(r.rcpi)) ]),
			E('td', { 'class': 'td' }, r.rate ? _('%d Mbit/s').format(Math.round(r.rate / 1000)) : ''),
			E('td', { 'class': 'td' }, r.live ? badge(_('online'), '#2e8540') : _('left %s').format(fmtAge(r.age)))
		]);
	}
	function head() {
		return E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th' }, _('Client')), E('th', { 'class': 'th' }, _('Wi-Fi')),
			E('th', { 'class': 'th' }, _('Signal (30 min)')), E('th', { 'class': 'th' }, _('Link rate')),
			E('th', { 'class': 'th' }, _('State'))
		]);
	}
	var live = rows.filter(function(r) { return r.live; }), gone = rows.filter(function(r) { return !r.live; });
	var order = ((topo && topo.nodes) || []).slice().sort(function(a, b) {
		return (a.depth - b.depth) || ((names[a.almac] || a.almac) > (names[b.almac] || b.almac) ? 1 : -1);
	}).filter(function(n) { return n.depth === 0 || n.age_s == null || n.age_s <= 180 || live.some(function(r) { return r.al == n.almac; }); });
	var out = [];
	order.forEach(function(n) {
		var mine = live.filter(function(r) { return r.al == n.almac; });
		out.push(E('h3', { 'style': 'margin:14px 0 4px' }, (names[n.almac] || n.almac) + ' \u2014 ' +
			(mine.length ? _('%d client(s)').format(mine.length) : _('no clients'))));
		if (mine.length)
			out.push(E('table', { 'class': 'table' }, [ head() ].concat(mine.map(line))));
	});
	var lost = live.filter(function(r) { return !order.some(function(n) { return n.almac == r.al; }); });
	if (lost.length) {
		out.push(E('h3', { 'style': 'margin:14px 0 4px' }, _('Other')));
		out.push(E('table', { 'class': 'table' }, [ head() ].concat(lost.map(line))));
	}
	if (gone.length) {
		var arrow = E('span', {}, GONE_OPEN ? '\u25be ' : '\u25b8 ');
		var body = E('div', { 'style': 'display:' + (GONE_OPEN ? 'block' : 'none') },
			E('table', { 'class': 'table' }, [ head() ].concat(gone.map(line))));
		out.push(E('div', { 'style': 'margin-top:14px' }, [
			E('a', { 'href': '#', 'style': 'text-decoration:none;cursor:pointer', 'click': function(ev) {
				ev.preventDefault(); GONE_OPEN = !GONE_OPEN;
				body.style.display = GONE_OPEN ? 'block' : 'none'; arrow.textContent = GONE_OPEN ? '\u25be ' : '\u25b8 ';
			} }, [ arrow, _('%d client(s) left in the last 24 hours').format(gone.length) ]), body ]));
	}
	return E('div', {}, out);
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return callState().then(function(st) {
			return Promise.all([ st, callClients(), callTopology() ]).then(function(r) {
				var data = r[1] || {};
				var macs = [];
				(data.mlds || []).forEach(function(m) {
					if (m.age_s < 86400) macs.push(m.mld_macaddr);
				});
				(data.stations || []).forEach(function(s) {
					if (!s.is_bsta && s.age_s < 86400) macs.push(s.macaddr);
				});
				macs = macs.slice(0, 12);
				return Promise.all(macs.map(function(m) {
					return callHistory(m, 32).then(function(h) {
						return { mac: m, samples: (h || {}).samples || [] };
					}, function() { return { mac: m, samples: [] }; });
				})).then(function(hs) {
					var hist = {};
					hs.forEach(function(h) { hist[h.mac] = h.samples; });
					return [ st, data, r[2], hist ];
				});
			});
		});
	},

	render: function(data) {
		var st = data[0], clients = data[1], topo = data[2], hist = data[3];
		if (!st || st.role == 'unconfigured')
			return E('div', { 'style': 'max-width:520px' }, [
				E('h2', {}, _('EasyMesh')),
				E('p', {}, _('This box is not part of a mesh yet. Set it up first - either as the first box of a new mesh, or by adding it to one you already have.')),
				E('a', { 'class': 'cbi-button cbi-button-apply', 'href': L.url('admin/network/easymesh/setup') }, _('Open the setup'))
			]);



		var box = E('div', {}, renderClients(clients, topo, hist));

		poll.add(function() {
			return Promise.all([ callClients(), callTopology() ]).then(function(r) {
				dom.content(box, renderClients(r[0], r[1], hist));
			});
		}, 15);

		var s = (clients || {}).summary || {};
		return E('div', {}, [
			E('h2', {}, _('Clients')),
			E('div', { 'class': 'cbi-section-descr' },
				_('%d online: %d with MLO (Wi-Fi 7, several links at once), %d on a single link. Names from DHCP; signal history from the controller.')
					.format(s.live || 0, s.mlo || 0, s.legacy || 0)),
			box
		]);
	}
});
