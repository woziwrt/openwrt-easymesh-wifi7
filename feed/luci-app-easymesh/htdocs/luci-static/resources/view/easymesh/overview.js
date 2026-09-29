// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

/* Overview, second layout (2026-09-25, approved by Petr the same day).
 * First screen is for a person, not an engineer: one sentence on how the
 * mesh is, the few numbers that matter, then the picture. Warnings fold into
 * one line, pairing a box folds behind a button, link labels say bands and
 * traffic in plain words and keep the engineering in the tooltip. An idle
 * mesh reads as quiet, never as 0.03 Mbit/s. Based on the opponent's mockup
 * of 2026-09-25 and our own list (8c, points 1, 2, 4). */

/* First screen of luci-app-easymesh: mesh health + node list.
 * Reads ONLY the easymesh ubus dictionary (easymesh-api package). */

var callState = rpc.declare({ object: 'easymesh', method: 'node_state' });
var callWpsOpen = rpc.declare({ object: 'easymesh', method: 'wps_open' });
var callSuggest = rpc.declare({ object: 'easymesh', method: 'suggest_address' });
var callForget = rpc.declare({ object: 'easymesh', method: 'forget_node', params: [ 'almac' ] });
var callRename = rpc.declare({ object: 'easymesh', method: 'rename', params: [ 'almac', 'name' ] });
var callAddStatus = rpc.declare({ object: 'easymesh', method: 'add_status' });
var callHealth = rpc.declare({ object: 'easymesh', method: 'health' });
var callNodes = rpc.declare({ object: 'easymesh', method: 'nodes' });
var callClients = rpc.declare({ object: 'easymesh', method: 'clients' });
var callTopology = rpc.declare({ object: 'easymesh', method: 'topology' });

var BAND = { 1: '2.4 GHz', 2: '5 GHz', 8: '6 GHz' };

function fmtAge(s) {
	if (s == null) return '—';
	if (s < 60) return _('%d s ago').format(s);
	if (s < 3600) return _('%d min ago').format(Math.round(s / 60));
	return _('%d h ago').format(Math.round(s / 3600));
}

var EXTRA_BY = {};          /* nodes API rows by AL-MAC, for the maker's name */
function nodeName(names, almac) {
	if (names && names[almac]) return names[almac];
	/* A box nobody named - typically a foreign agent - reads as its maker
	 * and the end of its address, not as a bare MAC (8c point 5). */
	var ex = EXTRA_BY[almac];
	if (ex && ex.manufacturer) return ex.manufacturer + ' \u00b7 ' + String(almac).slice(-5);
	return almac;
}

function card(num, label, cls) {
	return E('div', { 'class': 'ifacebox', 'style': 'margin:.4em;min-width:130px;text-align:center' }, [
		E('div', { 'class': 'ifacebox-head', 'style': 'font-weight:bold;font-size:1.4em;padding:.3em;' + (cls || '') }, [ num ]),
		E('div', { 'class': 'ifacebox-body', 'style': 'padding:.3em;color:#888' }, [ label ])
	]);
}

function countClients(c) {
	if (c && c.summary && c.summary.live != null)
		return c.summary.live;
	return ((c && c.stations) || []).filter(function(s) { return s.associated == 1 && !s.is_bsta; }).length;
}

/* The screen the user is already looking at, because pressing the first button
 * is what brought them here.
 *
 * Adding a box takes about four minutes and three restarts of a box in another
 * room, and for all of that a person who has just pressed two buttons is given
 * nothing at all. That silence is not neutral: it is when people press again,
 * and pressing again restarts a join that was going fine. So the controller says
 * what it knows, every few seconds, in the four states it can actually tell
 * apart - and says plainly which of them means "do it again".
 */
function renderAdd(st) {
	if (!st || !st.state || st.state == 'idle') return E([]);
	var cls = 'alert-message', body;
	/* Each of these confirms what the PERSON just did before it describes what
	 * the system is doing. Someone who has pressed a button wants to know the
	 * press landed; a status line about the state of a daemon answers a
	 * question they did not ask, and leaves the one they did ask open. */
	if (st.state == 'armed') {
		body = [ E('strong', {}, _('Button registered here.')), ' ',
			_('Now hold the WPS button on the new box for three seconds. Nothing else - no cable, and nothing to type in. After that it runs on its own for about four minutes and restarts three times; nothing here needs doing until this box says it is done.'),
			st.window_left_s != null
				? E('div', { 'style': 'color:#69707a;font-size:.9em;margin-top:.3em' },
					_('You have %d s left to do it. If it runs out, nothing is lost - just press here again.').format(st.window_left_s))
				: E([]) ];
	} else if (st.state == 'seen') {
		cls += ' info';
		body = [ E('strong', {}, _('The button on the new box registered too.')), ' ',
			_('Both presses landed - that is the part that needed your hands. The boxes are exchanging keys now; from here it runs on its own.') ];
	} else if (st.state == 'paired') {
		cls += ' info';
		body = [ E('strong', {}, _('Both buttons registered - the boxes have agreed.')), ' ',
			_('The new box is setting itself up now and restarts a few times on its own. It takes about four minutes from the second press. Leave both boxes alone; there is nothing more to press.') ];
	} else if (st.state == 'stalled') {
		cls += ' warning';
		/* No button of its own. This panel used to carry one, and "Pair a
		 * new box" sits a few lines further down doing the identical
		 * thing - two controls for one action, named differently, with
		 * nothing to tell a reader they are the same. Say which one to
		 * press instead. */
		body = [ E('strong', {}, _('The boxes agreed, but the new one has not finished.')),
			E('div', { 'style': 'margin-top:.3em' },
				_('It usually takes about four minutes and it has now been much longer. The mesh itself is unaffected - nothing here was changed. Press "Pair a new box" below to open the window again, then hold the button on the new box once more.')) ];
	} else if (st.state == 'settling') {
					/* Seen, but not finished. The box reports itself over 1905
					 * before its last reboot, so this is the window in which
					 * saying "done" would be disproved seconds later - the box
					 * goes away again and its lamp goes dark. Say what is
					 * happening instead, and keep the green for when it is
					 * actually true. */
					cls += ' info';
					body = [
						E('strong', {}, _('The new box is here and finishing up.')),
						' ',
						_('It has the credentials and restarts once more to put them into service. Its lamp goes dark during that - that is the restart, not a failure. Wait for the green line here.')
					];
				} else if (st.state == 'joined') {
		cls += ' success';
		body = [ E('strong', {}, _('Done - the new box is in the mesh.')), ' ',
			_('It came in as "%s" and is carrying traffic. Rename it with the pencil in the list below if you want it called something else.').format(st.name || st.almac) ];
	} else if (st.state == 'nobody') {
		cls += ' warning';
		body = [ E('strong', {}, _('The other button was never pressed.')),
			E('div', { 'style': 'margin-top:.3em' },
				_('Nothing is broken and nothing was changed here. Press "Pair a new box" below, then hold the WPS button on the new box for three seconds - it has to be held, a short press does something else.')) ];
	} else {
		return E([]);
	}
	return E('div', { 'class': cls, 'style': 'margin-bottom:1em' }, body);
}

function renderHealth(h, clients) {
	var warn = (h.warnings || []).filter(function(w) { return w && w.length });
	return E('div', {}, [
		E('div', { 'style': 'display:flex;flex-wrap:wrap' }, [
			card(String(h.num_nodes || 0), _('nodes in mesh'), 'color:#2e8540'),
			card(String(h.stale_nodes || 0), _('silent nodes'), h.stale_nodes ? 'color:#b58900' : 'color:#2e8540'),
			card(String(warn.length), _('warnings'), warn.length ? 'color:#c0392b' : 'color:#2e8540'),
			card(String(countClients(clients)), _('active clients'))
		]),
		warn.length ? E('div', { 'class': 'alert-message warning' },
			warn.map(function(w) { return E('div', {}, [ w ]); })) : E([])
	]);
}


function esc(t) {
	return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/* Traffic per backhaul leg, from two samples of its byte counters.
 *
 * linkstat reports the leg's cumulative rx/tx bytes (iw station dump), and a
 * new sample reaches the controller every 30 s while this page polls every
 * 15 s. So the rate is taken between two samples with different last_seen,
 * and kept until the next one arrives. The first half minute on the page has
 * no rate yet and says so. A counter that went backwards is a reassociation:
 * start again from it instead of drawing a negative rate. */
var legSeen = {};
function legRate(almac, g, rx, tx, ts) {
	var k = almac + '/' + g.id, prev = legSeen[k];
	if (!ts || isNaN(rx) || isNaN(tx)) return;
	if (prev && ts == prev.ts) {
		g.down = prev.down; g.up = prev.up; g.mbps = prev.mbps;
		return;
	}
	var cur = { ts: ts, rx: rx, tx: tx, down: null, up: null, mbps: null };
	if (prev && ts > prev.ts && rx >= prev.rx && tx >= prev.tx) {
		var dt = ts - prev.ts;
		cur.down = (rx - prev.rx) * 8 / dt / 1e6;
		cur.up = (tx - prev.tx) * 8 / dt / 1e6;
		cur.mbps = cur.down + cur.up;
	}
	legSeen[k] = cur;
	g.down = cur.down; g.up = cur.up; g.mbps = cur.mbps;
}

function fmtMbps(m) {
	return m < 0.1 ? m.toFixed(2) : m < 10 ? m.toFixed(1) : Math.round(m).toString();
}

var GW_AL = null;
var NOTES_OPEN = false;       /* the notes line keeps its state across redraws */
var CLIENTS_BY = {};       /* AL-MAC -> names of the clients live on that box */
function clientsByNode(c) {
	var by = {}, dhcp = (c && c.dhcp_names) || {}, seen = {};
	function add(al, mac, name) {
		if (!al || seen[mac]) return;
		seen[mac] = true;
		(by[al] = by[al] || []).push(name || dhcp[mac] || mac);
	}
	((c && c.mlds) || []).forEach(function(m) {
		var age = Math.min(m.sta_age_s != null ? m.sta_age_s : 99999, m.leg_age_s != null ? m.leg_age_s : 99999);
		if (age < 300) add(m.sta_agent_almac || m.agent_almac, m.mld_macaddr, m.hostname);
	});
	((c && c.stations) || []).forEach(function(st) {
		if (!st.is_bsta && st.associated == 1 && (st.age_s == null || st.age_s < 300))
			add(st.agent_almac, st.macaddr, st.hostname);
	});
	return by;
}          /* AL-MAC of the box the clients' gateway is on */
var BAND_H = { 1: '2.4 GHz', 2: '5 GHz', 8: '6 GHz' };

/* Rename in place (2026-09-26, pair-as-a-user test, finding #46). The native
 * prompt() it replaces blocked the whole page and did not look like part of
 * LuCI. The pencil turns the name into a text field: Enter or Save writes
 * it, Esc or Cancel puts the name back, an error is said next to the field.
 * While a field is open the 15 s poll leaves the table alone, or it would
 * wipe what the user is typing. */
var EDITING = false;
function renameButton(n, names) {
	var btn = E('button', {
		'class': 'cbi-button',
		'style': 'margin-left:.5em;padding:0 .4em;line-height:1.4',
		'title': _('Rename this node')
	}, '\u270e');
	btn.addEventListener('click', function() {
		var td = btn.parentNode, shown = td.firstChild;
		var cur = nodeName(names, n.almac);
		var input = E('input', { 'type': 'text', 'class': 'cbi-input-text',
			'style': 'width:14em', 'maxlength': '63',
			'value': cur === n.almac ? '' : cur,
			'placeholder': _('e.g. living-room') });
		var msg = E('div', { 'style': 'font-size:12px;margin-top:3px;color:#69707a' },
			_('Written into the box itself as its hostname, so it stays with the box.'));
		var save = E('button', { 'class': 'cbi-button cbi-button-apply', 'style': 'margin-left:.3em' }, _('Save'));
		var cancel = E('button', { 'class': 'cbi-button', 'style': 'margin-left:.3em' }, _('Cancel'));
		var form = E('div', {}, [ input, save, cancel, msg ]);
		var close = function() {
			EDITING = false;
			td.removeChild(form);
			shown.style.display = ''; btn.style.display = '';
		};
		var go = function() {
			var v = input.value.trim();
			if (!v || v === cur) { close(); return; }
			save.disabled = cancel.disabled = input.disabled = true;
			msg.style.color = '#69707a';
			msg.textContent = _('Saving\u2026');
			/* An error used to be swallowed by an unconditional reload.
			 * A rename that did not happen must not look like one that did. */
			callRename(n.almac, v).then(function(r) {
				if (r && r.error) {
					save.disabled = cancel.disabled = input.disabled = false;
					msg.style.color = '#c0392b';
					msg.textContent = _('The rename did not go through: %s').format(r.error);
					return;
				}
				EDITING = false;
				location.reload();
			}, function() {
				save.disabled = cancel.disabled = input.disabled = false;
				msg.style.color = '#c0392b';
				msg.textContent = _('The rename did not go through - the controller did not answer.');
			});
		};
		save.addEventListener('click', go);
		cancel.addEventListener('click', close);
		input.addEventListener('keydown', function(ev) {
			if (ev.key === 'Enter') go();
			else if (ev.key === 'Escape') close();
		});
		EDITING = true;
		shown.style.display = 'none'; btn.style.display = 'none';
		td.insertBefore(form, td.firstChild);
		input.focus(); input.select();
	});
	return btn;
}

/* A leg's quality, fields 7-10 of bsta_link_detail (2026-09-26): the PHY
 * rate the box receives (down) and sends (up) on it, its signal and the
 * spread between its receive chains. Beacons and tx_failed cannot tell a
 * slow leg from a good one - bedroom's 6 GHz leg heard 97 % of its beacons
 * while it received at MCS 0, one stream, 144 Mbit/s. Empty on a box whose
 * linkstat is older: then nothing is claimed either way. */
var SLOW_MBIT = 200;
/* ...and a leg this faint is weak whatever its rate says: the kitchen 6 GHz
 * leg at -82 dBm carried no data frame at all downstream, so it had no rate
 * to be slow with (2026-09-26). */
var WEAK_DBM = -80;
/* ...but a rate says something only while the leg carries traffic. An idle
 * leg sends only keep-alive frames, at 6-72 Mbit/s whatever it can do: on
 * 2026-09-27 the kitchen 6 GHz leg read 72/144 Mbit/s idle at -62 dBm and
 * went to 1297 Mbit/s the moment iperf ran over it - and the picture called
 * it slow the whole time. Idle, only the signal is judged. */
var BUSY_MBIT = 5;
function legPhy(g, f) {
	var num = function(v) { return v === '' || v == null ? null : +v; };
	g.phyDown = num(f[7]); g.phyUp = num(f[8]); g.rssi = num(f[9]);
	g.spread = num(f[10]);
	if (g.phyDown === 0) g.phyDown = null;
	if (g.phyUp === 0) g.phyUp = null;
	if (g.spread != null && g.spread < 0) g.spread = null;
	var lo = Math.min(g.phyDown != null ? g.phyDown : 1e9, g.phyUp != null ? g.phyUp : 1e9);
	g.phyMin = lo < 1e9 ? lo : null;
	g.slow = g.phyMin != null && g.phyMin < SLOW_MBIT && g.mbps != null && g.mbps >= BUSY_MBIT;
	g.faint = g.rssi != null && g.rssi <= WEAK_DBM;
	if (g.faint) g.slow = true;
	return g;
}

/* One pass over the picture's own data: who is up, which legs are weak,
 * how much the backhaul carries right now. Same thresholds as the lines
 * (a leg is weak under 80 % of its beacons, dead when not up/degraded). */
function meshStatus(topo) {
	var names = (topo && topo.names) || {}, nodes = (topo && topo.nodes) || [],
	    links = (topo && topo.links) || [], parentOf = {};
	links.forEach(function(l) { parentOf[l.child_almac] = l.parent_almac; });
	var r = { total: 0, up: 0, offline: [], weak: [], mbps: 0, measuring: false };
	nodes.forEach(function(n) {
		r.total++;
		if (n.depth !== 0 && n.age_s != null && n.age_s > 180) {
			r.offline.push(nodeName(names, n.almac));
			return;
		}
		r.up++;
		String(n.bsta_link_detail || '').split(',').filter(function(x) { return x; })
			.forEach(function(x) {
				var f = x.split(':');
				var g = { id: +f[0], state: f[1], band: +f[2],
					beacon: f[3] === '' || f[3] == null ? null : +f[3] };
				legRate(n.almac, g, +f[4], +f[5], +f[6]);
				legPhy(g, f);
				if (g.mbps != null) r.mbps += g.mbps; else r.measuring = true;
				var dead = (g.state != 'up' && g.state != 'degraded');
				var deaf = !dead && g.beacon != null && g.beacon < 80;
				if (dead || deaf || g.slow)
					r.weak.push({ child: nodeName(names, n.almac),
						parent: nodeName(names, parentOf[n.almac]),
						band: BAND_H[g.band] || '?', beacon: g.beacon, dead: dead,
						deaf: deaf, phy: g.phyMin, rssi: g.rssi, faint: g.faint });
			});
	});
	return r;
}

function renderHeadline(topo, health) {
	var m = meshStatus(topo), level, text, why = [];
	if (m.offline.length) {
		level = 'bad';
		text = _('%d box(es) not responding: %s. The rest of the mesh keeps working.')
			.format(m.offline.length, m.offline.join(', '));
	} else if (m.weak.length) {
		level = 'warn';
		text = m.weak.length == 1 ? _('Mesh is working, one link is weak.')
			: _('Mesh is working, %d links are weak.').format(m.weak.length);
		m.weak.slice(0, 3).forEach(function(w) {
			why.push(w.dead
				? _('%s \u2194 %s: the %s link is down, traffic uses the other band.').format(w.child, w.parent, w.band)
				: w.deaf
				? _('%s \u2194 %s: the %s link hears only %d %% of its beacons.').format(w.child, w.parent, w.band, w.beacon)
				: w.faint
				? _('%s \u2194 %s: the %s link is very faint (signal %d dBm) - the boxes are too far apart for this band.').format(w.child, w.parent, w.band, w.rssi)
				: (w.rssi != null
					? _('%s \u2194 %s: the %s link runs at only %d Mbit/s (signal %d dBm) - the boxes may be too far apart for this band.').format(w.child, w.parent, w.band, w.phy, w.rssi)
					: _('%s \u2194 %s: the %s link runs at only %d Mbit/s.').format(w.child, w.parent, w.band, w.phy)));
		});
		if (m.weak.length > 3) why.push(_('and %d more').format(m.weak.length - 3));
	} else {
		level = 'ok';
		text = _('Mesh is working. All %d boxes online, every link healthy.').format(m.up);
	}
	var C = { ok: [ '#2e8540', '#eaf6ee' ], warn: [ '#8a6d00', '#fff6dd' ], bad: [ '#c0392b', '#fdecea' ] }[level];
	return E('div', { 'style': 'border-left:5px solid ' + C[0] + ';background:' + C[1] +
		';padding:10px 14px;border-radius:6px;margin:6px 0 10px' }, [
		E('div', { 'style': 'font-size:16px;font-weight:bold;color:' + C[0] }, text),
		why.length ? E('div', { 'style': 'margin-top:4px;font-size:13px;color:#24292f' },
			why.map(function(w) { return E('div', {}, w); })) : E([])
	]);
}

function renderNow(topo, health, clients) {
	var m = meshStatus(topo), names = (topo && topo.names) || {};
	var gw = health && health.gateway;
	var traffic = m.mbps >= 1 ? fmtMbps(m.mbps) + ' Mbit/s'
		: m.measuring ? _('measuring\u2026') : _('quiet');
	var warn = ((health && health.warnings) || []).filter(function(w) { return w && w.length; });
	return E('div', {}, [
		E('div', { 'style': 'display:flex;flex-wrap:wrap' }, [
			card(m.up + ' / ' + m.total, _('boxes online'), m.offline.length ? 'color:#c0392b' : 'color:#2e8540'),
			card(String(countClients(clients)), _('clients online')),
			card(traffic, _('moving through the backhaul now'), m.mbps >= 1 ? 'color:#2f7fc1' : 'color:#69707a'),
			card(gw ? nodeName(names, gw.almac) : '\u2014', _('internet goes out via'))
		]),
		warn.length ? (function() {
			/* Not a <details>: the page redraws this block every 15 s, and
			 * a redrawn <details> comes back closed - clicking it looked like
			 * nothing happened (Petr, 2026-09-25). The open state lives here
			 * and survives the redraw. */
			var arrow = E('span', {}, NOTES_OPEN ? '\u25be ' : '\u25b8 ');
			/* No colour of its own: LuCI runs light and dark themes, and a
			 * fixed dark grey was invisible on the dark one (Petr, 2026-09-25:
			 * "the page only moves down a bit"). */
			var body = E('div', { 'style': 'margin:4px 0 0 18px;display:' +
				(NOTES_OPEN ? 'block' : 'none') },
				warn.map(function(w) { return E('div', {}, [ w ]); }));
			var head = E('a', { 'href': '#', 'style': 'color:#8a6d00;text-decoration:none;cursor:pointer',
				'click': function(ev) {
					ev.preventDefault();
					NOTES_OPEN = !NOTES_OPEN;
					body.style.display = NOTES_OPEN ? 'block' : 'none';
					arrow.textContent = NOTES_OPEN ? '\u25be ' : '\u25b8 ';
				} }, [ arrow, '\u26a0 ' + _('%d note(s)').format(warn.length) ]);
			return E('div', { 'style': 'margin:4px 0 8px' }, [ head, body ]);
		})() : E([])
	]);
}

function renderTopology(topo, nodesData) {
	var names = (topo && topo.names) || {};
	var addrs = (topo && topo.addrs) || {};
	var nodes = (topo && topo.nodes) || [];
	var links = (topo && topo.links) || [];
	var extra = {};
	(((nodesData || {}).nodes) || []).forEach(function(n) { extra[n.almac] = n; });
	EXTRA_BY = extra;

		var parentOf = {}, edgeState = {};
		links.forEach(function(l) {
			parentOf[l.child_almac] = l.parent_almac;
			edgeState[l.child_almac] = l.parent_state;
		});

		/* A node with no edge used to get depth 0 and was drawn next to
		 * the controller, as if it were a second root. It has no place in
		 * the tree, so it gets a row of its own under it. */
		/* Silent for longer than the controller keeps a node (180 s) is
		 * offline. The DB still holds its last edge for a while on purpose,
		 * so a box that was unplugged kept being drawn on its cable; now
		 * it says what it is. */
		var offline = {};
		nodes.forEach(function(n) {
			if (n.depth !== 0 && n.age_s != null && n.age_s > 180)
				offline[n.almac] = true;
		});

		var unplaced = {};
		nodes.forEach(function(n) {
			if (!parentOf[n.almac] && n.depth !== 0)
				unplaced[n.almac] = true;
		});

		/* Depth comes from the edges we are about to draw, not from the
		 * stored field. The two disagreed on 2026-08-09 - the node table
		 * said depth 2 where the link table said 3 - and a tree laid out
		 * by one and wired by the other draws a child beside its parent
		 * instead of below it. */
		function depthOf(almac, seen) {
			var p = parentOf[almac];
			if (!p || p == almac || (seen && seen[almac])) return 0;
			seen = seen || {};
			seen[almac] = true;
			return depthOf(p, seen) + 1;
		}

		/* A parent that has dropped out of the model is still carrying
		 * traffic: its children stay associated to it and data keeps
		 * flowing through. Without a box of its own, every one of those
		 * children draws at the right depth with no line at all, and the
		 * map reads as a shattered mesh when nothing is broken.
		 * Seen 2026-09-08 - mapagent was stopped on one node, three
		 * children kept running through it, and the picture showed them
		 * floating. Draw the gap instead of hiding it. */
		var known = {};
		nodes.forEach(function(n) { known[n.almac] = true; });
		var drawn = nodes.slice();
		links.forEach(function(l) {
			if (l.parent_almac && !known[l.parent_almac]) {
				known[l.parent_almac] = true;
				drawn.push({ almac: l.parent_almac, silent: true });
			}
		});

		var depthOfNode = {}, byDepth = {};
		/* Walk `drawn`, not `nodes`: it carries the silent parents added just
		 * above, and those need a depth and a position like anything else.
		 * Walking `nodes` here dropped them back out of the picture, which is
		 * the exact failure the silent-parent code was written for - children
		 * at the right depth with no line to anything, reading as a mesh in
		 * pieces when nothing was broken (2026-09-08).
		 *
		 * Merge resolution 2026-09-21: two lines of development reached the
		 * silent parent independently and then diverged on this one loop. */
		var unplacedRow = [];
		drawn.forEach(function(n) {
			if (unplaced[n.almac]) { unplacedRow.push(n); return; }
			var dep = depthOfNode[n.almac] = depthOf(n.almac);
			(byDepth[dep] = byDepth[dep] || []).push(n);
		});

	/* BOXH grew from 56 to 70 for the address line. VGAP stays: 108 - 70
	 * still leaves 38px of air between rows for the link labels. */
	var W = 940, BOXW = 190, BOXH = 70, VGAP = 108;
	var pos = {};
	var depths = Object.keys(byDepth).map(Number).sort(function(a, b) { return a - b });
	depths.forEach(function(d) {
		var row = byDepth[d];
		row.sort(function(a, b) {
			var pa = pos[parentOf[a.almac]], pb = pos[parentOf[b.almac]];
			return ((pa ? pa.x : 0) - (pb ? pb.x : 0)) || (a.almac > b.almac ? 1 : -1);
		});
		row.forEach(function(n, i) {
			pos[n.almac] = { x: (i + 1) * W / (row.length + 1), y: 40 + d * VGAP };
		});
	});

	if (unplacedRow.length) {
		var ud = depths.length ? depths[depths.length - 1] + 1 : 1;
		unplacedRow.sort(function(a, b) { return a.almac > b.almac ? 1 : -1 });
		unplacedRow.forEach(function(n, i) {
			pos[n.almac] = { x: (i + 1) * W / (unplacedRow.length + 1), y: 40 + ud * VGAP };
		});
		depths.push(ud);
	}

	var H = 40 + (depths.length ? (depths[depths.length - 1] + 1) * VGAP : VGAP);
	var BAND = { 1: '2.4G', 2: '5G', 8: '6G' };
	var LEG_COLOR = { 1: '#1f9e9e', 2: '#2f7fc1', 8: '#7b3fb5' };
	function parseLegs(almac, detail) {
		return String(detail || '').split(',').filter(function(x) { return x; })
			.map(function(x) {
				var f = x.split(':');
				var g = { id: +f[0], state: f[1], band: +f[2],
					beacon: f[3] === '' || f[3] == null ? null : +f[3],
					down: null, up: null, mbps: null,
					seen: f[6] === '' || f[6] == null ? null : +f[6] };
				legRate(almac, g, +f[4], +f[5], +f[6]);
				return legPhy(g, f);
			})
			.sort(function(a, b) { return a.id - b.id; });
	}
	function legTitle(g) {
		return (BAND[g.band] || '?') + ' link ' + g.id + ': ' + g.state +
			(g.beacon != null ? ', beacons ' + g.beacon + ' %' : '') +
			(g.mbps == null ? ', traffic: measuring'
				: ', down ' + fmtMbps(g.down) + ' / up ' + fmtMbps(g.up) + ' Mbit/s') +
			(g.phyMin != null ? ', link rate down ' + (g.phyDown != null ? g.phyDown : '?') +
				' / up ' + (g.phyUp != null ? g.phyUp : '?') + ' Mbit/s' + (g.slow ? ' (slow)' : '') : '') +
			(g.rssi != null ? ', signal ' + g.rssi + ' dBm' : '') +
			(g.spread != null ? ', antennas differ by ' + g.spread + ' dB' : '') +
			/* The picture is up to about a minute and a half behind the air:
			 * each node measures over 30 s, a collection round on the
			 * controller takes 20-30 s plus a 30 s pause (measured 2026-09-27:
			 * rows 12-49 s old), and this page asks every 10 s. Saying how old
			 * the numbers are keeps a user from reading a past state as the
			 * present one. */
			(g.seen ? ', collected ' + Math.max(0, Math.round(Date.now() / 1000 - g.seen)) +
				' s ago (measured over 30 s)' : '');
	}
	var out = [];

	links.forEach(function(l) {
		var c = pos[l.child_almac], p = pos[l.parent_almac];
		if (!c || !p) return;
		var n = nodes.filter(function(x) { return x.almac == l.child_almac; })[0] || {};
		/* How many legs are UP, not how many the MLD was built from.
		 *
		 * bsta_links is num_bsta out of the bSTA-MLD Config TLV and describes
		 * construction: it is 2 on every box in this lab, 2 on the MediaTek
		 * box that has one leg, and 2 on the row a box left behind when it
		 * went away. The condition was therefore true always, and a marker
		 * that is always true says nothing. On 2026-09-21 the driver declared
		 * a 6 GHz leg lost and this drawing did not change, because nothing
		 * about num_bsta can change.
		 *
		 * When the controller cannot say - an older controller, or a node
		 * nobody has heard from for 90 s - we draw ONE line rather than
		 * guessing two. An unknown leg is not a leg. */
		var live = n.bsta_links_live;
		var mlo = (live != null) && live >= 2;
		var legs = parseLegs(l.child_almac, n.bsta_link_detail);
			var claimed = (l.parent_state != 'unconfirmed' && l.parent_state != 'conflict');
			/* Where the edge came from decides how much ink it gets:
			 * confirmed by the child or by the parent is a link, inferred
			 * from 1905 neighbours is a good guess, a conflict is a fault. */
			var wired = (l.media_type != null && l.media_type < 256 &&
				String(l.source || '').indexOf('neighbor') == 0);
			if (offline[l.child_almac]) {
				out.push('<line x1="' + c.x + '" y1="' + c.y + '" x2="' + p.x + '" y2="' +
					(p.y + BOXH) + '" stroke="#8a939c" stroke-width="1.5" stroke-dasharray="2 6"/>');
			} else if (l.parent_state == 'conflict') {
				out.push('<line x1="' + c.x + '" y1="' + c.y + '" x2="' + p.x + '" y2="' +
					(p.y + BOXH) + '" stroke="#c0392b" stroke-width="2" stroke-dasharray="6 5"/>');
			} else if (wired) {
				/* A cable. Solid when both ends list each other, dashed
				 * when only one side says so. */
				out.push('<line x1="' + c.x + '" y1="' + c.y + '" x2="' + p.x + '" y2="' +
					(p.y + BOXH) + '" stroke="#3f8f6b" stroke-width="3"' +
					(l.parent_state == 'inferred' ? ' stroke-dasharray="3 4"' : '') + '/>');
			} else if (l.parent_state == 'inferred' || l.parent_state == 'mutual') {
				out.push('<line x1="' + c.x + '" y1="' + c.y + '" x2="' + p.x + '" y2="' +
					(p.y + BOXH) + '" stroke="#8a939c" stroke-width="2"' +
					(l.parent_state == 'inferred' ? ' stroke-dasharray="3 4"' : '') + '/>');
			} else if (!claimed) {
				/* Nobody but the model believes this edge. Drawn anyway,
				 * because hiding it would throw away the only hint we
				 * have - but never with the weight of a measured link. */
				out.push('<line x1="' + c.x + '" y1="' + c.y + '" x2="' + p.x + '" y2="' +
					(p.y + BOXH) + '" stroke="#b58900" stroke-width="2" stroke-dasharray="6 5"/>');
			} else if (legs.length) {
			/* One line per leg, from what each leg measured in the last
			 * window. Until 2026-09-24 an MLO edge was two fixed lines that
			 * said how many legs were alive, and nothing about which of them
			 * carried the traffic: a leg that heard 3 % of its beacons, or
			 * one the traffic had left, looked exactly like the busy one.
			 * Colour is the band, width is the traffic, orange dashes mean
			 * the leg hears under half of its beacons, grey dashes mean it
			 * is not alive at all, long dashes in the band colour mean it is
			 * alive but slow (link rate under SLOW_MBIT). Hover a line for
			 * the numbers. */
			legs.forEach(function(g, i) {
				var off = (i - (legs.length - 1) / 2) * 10;
				var dead = (g.state != 'up' && g.state != 'degraded');
				var deaf = !dead && g.beacon != null && g.beacon < 50;
				var w = (dead || g.mbps == null) ? 1.5 : 1.5 + Math.min(6, Math.log(1 + g.mbps) / Math.LN2);
				var col = dead ? '#8a939c' : deaf ? '#d9822b' : (LEG_COLOR[g.band] || '#5a7a99');
				out.push('<line x1="' + (c.x + off) + '" y1="' + c.y + '" x2="' + (p.x + off) +
					'" y2="' + (p.y + BOXH) + '" stroke="' + col + '" stroke-width="' + w.toFixed(1) + '"' +
					(dead ? ' stroke-dasharray="2 6"' : deaf ? ' stroke-dasharray="5 4"' : g.slow ? ' stroke-dasharray="9 5"' : '') +
					' stroke-linecap="round"><title>' + esc(legTitle(g)) + '</title></line>');
			});
		} else {
			out.push('<line x1="' + c.x + '" y1="' + c.y + '" x2="' + p.x + '" y2="' +
				(p.y + BOXH) + '" stroke="#5a7a99" stroke-width="2"/>');
		}
		var STATE_LBL = { parent: ' \u00b7 by parent', mutual: ' \u00b7 seen by both',
			inferred: ' \u00b7 inferred', conflict: ' \u00b7 conflict',
			unconfirmed: ' \u00b7 unconfirmed' };
		/* wifi_hops counts Wi-Fi hops only, so a cable always said "0 hop"
		 * and read like a fault. Say it only when there is a hop to count. */
		var lbl = (wired ? 'wired'
			: legs.length ? (mlo ? 'MLO \u00b7 ' : '') + legs.map(function(g) {
				return (BAND[g.band] || '?') + ' ' +
					((g.state != 'up' && g.state != 'degraded') ? g.state
					: g.mbps == null ? '\u2026' : fmtMbps(g.mbps));
			  }).join(' + ') + ' Mbit/s'
			: mlo ? 'MLO \u00b7 ' + live + '/' + n.bsta_links + ' links'
			: (live === 1 && (n.bsta_links || 0) >= 2)
				? _('1 of %d legs').format(n.bsta_links)
			: (BAND[n.backhaul_band] || '')) +
				(l.wifi_hops ? ' \u00b7 ' + l.wifi_hops + ' hop' : '') +
				(offline[l.child_almac] ? ' \u00b7 offline' : (STATE_LBL[l.parent_state] || ''));
		/* v2: the label says bands and traffic in plain words; the
		 * engineering (MLO, how the edge is known, hops) moves to the
		 * tooltip of the label. */
		var tech = lbl;
		if (offline[l.child_almac]) lbl = _('offline');
		else if (wired) lbl = _('cable');
		else if (legs.length) {
			var sum = 0, have = false, notes = [];
			legs.forEach(function(g) {
				if (g.mbps != null) { sum += g.mbps; have = true; }
				if (g.state != 'up' && g.state != 'degraded') notes.push(BAND_H[g.band] + ' ' + _('down'));
				else if (g.beacon != null && g.beacon < 50) notes.push(BAND_H[g.band] + ' ' + _('weak'));
				else if (g.faint) notes.push(BAND_H[g.band] + ' ' + _('weak signal'));
				else if (g.slow) notes.push(BAND_H[g.band] + ' ' + _('slow'));
			});
			/* Idle is not broken: with nothing flowing, say what the link
			 * could carry - its PHY rate as the parent last saw it - and call
			 * it a link rate, because about a third of it arrives as TCP. */
			var rate = n.bh_dl_kbps ? Math.round(n.bh_dl_kbps / 1000) : null;
			lbl = legs.map(function(g) { return (BAND[g.band] || '?').replace('G', ''); }).join(' + ') + ' GHz' +
				(have && sum >= 1 ? ' \u00b7 ' + fmtMbps(sum) + ' Mbit/s'
				 : rate ? ' \u00b7 ' + _('link %d Mbit/s').format(rate) : '') +
				(notes.length ? ' \u00b7 ' + notes.join(', ') : '');
			if (n.bh_dl_kbps || n.bh_ul_kbps)
				tech += ' | ' + _('link rate (PHY) down %d / up %d Mbit/s - real throughput is lower, about a third')
					.format(Math.round((n.bh_dl_kbps || 0) / 1000), Math.round((n.bh_ul_kbps || 0) / 1000));
		}
		var LBL_COLOR = { conflict: '#c0392b', unconfirmed: '#b58900' };
		/* At the middle of the edge the labels of two siblings meet under
		 * their parent and run into each other (2026-09-18, a BPI-R4 Pro 8X with two
		 * children). A third of the way up from the child they are as far
		 * apart as the children are, and set on the outer side. */
		var lx = c.x + (p.x - c.x) / 3, ly = c.y + (p.y + BOXH - c.y) / 3;
		var left = c.x < p.x;
		/* A child straight under its parent has no outer side, and its
		 * label went right - into its sibling's label (kitchen under
		 * corridor next to hall, 2026-09-26). Put it on the side where no
		 * sibling is. */
		if (Math.abs(c.x - p.x) < 1) {
			var sibR = false, sibL = false;
			links.forEach(function(o) {
				var q = pos[o.child_almac];
				if (o.parent_almac != l.parent_almac || o.child_almac == l.child_almac || !q) return;
				if (q.x > c.x) sibR = true; else if (q.x < c.x) sibL = true;
			});
			left = sibR && !sibL;
		}
		out.push('<text x="' + (lx + (left ? -8 : 8)) + '" y="' + ly +
			'" text-anchor="' + (left ? 'end' : 'start') + '"' +
			' font-size="11" fill="' + (LBL_COLOR[l.parent_state] || '#69707a') +
				'">' + esc(lbl) + '<title>' + esc(tech) + '</title></text>');
	});

	drawn.forEach(function(n) {
		var q = pos[n.almac]; if (!q) return;
		if (n.silent) {
			/* Known only from the edges of its children: the model has no
			 * record of it any more. Drawn hollow, so it is plain that the
			 * mesh runs through something the controller cannot see. */
			out.push('<rect x="' + (q.x - BOXW / 2) + '" y="' + q.y + '" width="' + BOXW +
				'" height="' + BOXH + '" rx="8" fill="#f6f7f8" stroke="#b58900" ' +
				'stroke-width="2" stroke-dasharray="6 5"/>');
			out.push('<text x="' + q.x + '" y="' + (q.y + 26) + '" text-anchor="middle" ' +
				'font-size="13" font-weight="bold" fill="#8a6d00">' +
				esc(nodeName(names, n.almac)) + '</text>');
			out.push('<text x="' + q.x + '" y="' + (q.y + 44) + '" text-anchor="middle" ' +
				'font-size="10" fill="#8a6d00">' + esc(_('silent - still carrying traffic')) +
				'</text>');
			return;
		}
		var isCtrl = (n.depth === 0);
		var x = q.x - BOXW / 2, y = q.y;
		var ex = extra[n.almac] || {};
		out.push('<rect x="' + x + '" y="' + y + '" width="' + BOXW + '" height="' + BOXH +
			'" rx="8" fill="' + (isCtrl ? '#2563b0' : '#ffffff') + '" stroke="' +
			(isCtrl ? '#2563b0' : unplaced[n.almac] ? '#b58900' : '#5a7a99') + '" stroke-width="2"' +
			(unplaced[n.almac] ? ' stroke-dasharray="6 5"' : '') + '><title>' +
			esc((CLIENTS_BY[n.almac] || []).length
				? _('Clients here: %s').format(CLIENTS_BY[n.almac].join(', '))
				: _('No clients here right now')) + '</title></rect>');
		if (unplaced[n.almac])
			out.push('<text x="' + q.x + '" y="' + (y - 6) + '" text-anchor="middle" font-size="10" ' +
				'fill="#b58900">' + esc(offline[n.almac] ? _('offline')
					: _('not placed in the tree')) + '</text>');
		out.push('<text x="' + q.x + '" y="' + (y + 21) + '" text-anchor="middle" font-size="13" ' +
			'font-weight="bold" fill="' + (isCtrl ? '#ffffff' : '#24292f') + '">' +
			esc(nodeName(names, n.almac)) + '</text>');
		out.push('<text x="' + q.x + '" y="' + (y + 37) + '" text-anchor="middle" font-size="10" fill="' +
			(isCtrl ? '#cfe0ee' : '#69707a') + '">' +
			esc((isCtrl ? _('main box') + ' \u00b7 '
				: offline[n.almac] ? _('offline') + ' \u00b7 '
				: depthOfNode[n.almac] + ' ' + (depthOfNode[n.almac] == 1 ? _('hop') : _('hops')) + ' \u00b7 ') +
				(ex.clients || 0) + ' ' + ((ex.clients || 0) == 1 ? _('client') : _('clients')) +
				(GW_AL && GW_AL == n.almac ? ' \u00b7 ' + _('internet') : '')) +
				'</text>');
		/* The address, in small type under the name. The picture already
		 * says which box is which; this says where to reach it - and since
		 * addresses are claimed by the boxes themselves rather than typed by
		 * anyone, this is the only place they are written down. */
		if (addrs[n.almac])
			out.push('<text x="' + q.x + '" y="' + (y + 52) + '" text-anchor="middle" font-size="10" ' +
				'font-family="monospace" fill="' + (isCtrl ? '#cfe0ee' : '#69707a') + '">' +
				esc(addrs[n.almac]) + '</text>');
		if (!isCtrl) {
			var age = n.age_s, col = (age == null || age > 180) ? '#c0392b'
				: (age > 60 ? '#b58900' : '#2e8540');
			out.push('<circle cx="' + (q.x - 34) + '" cy="' + (y + 61) + '" r="4" fill="' + col + '"/>');
			out.push('<text x="' + (q.x - 26) + '" y="' + (y + 64) + '" font-size="9" fill="#69707a">' +
				esc(fmtAge(age)) + '</text>');
		}
	});

	var box = E('div', { 'style': 'overflow-x:auto;position:relative' });
	box.innerHTML = '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%" ' +
		'style="max-height:420px;background:#fbfcfd;border:1px solid #e0e4e8;border-radius:8px">' +
		out.join('') + '</svg>';
	box.appendChild(topoLegend(LEG_COLOR));
	return box;
}

/* A small key in the corner of the picture, so a user can tell what the
 * colours and lines mean (until 2026-09-27 only the two of us knew). The
 * samples use the same colours and dashes as the drawing. Text colour comes
 * from the theme and the background is a translucent grey, so the key fits
 * both the light and the dark theme. */
function topoLegend(legColor) {
	var line = function(col, w, dash) {
		return '<svg width="22" height="10" style="vertical-align:middle">' +
			'<line x1="2" y1="5" x2="20" y2="5" stroke="' + col + '" stroke-width="' + w + '"' +
			(dash ? ' stroke-dasharray="' + dash + '"' : '') + ' stroke-linecap="round"/></svg>';
	};
	var rows = [
		line(legColor[1], 3) + ' 2.4 ' + line(legColor[2], 3) + ' 5 ' + line(legColor[8], 3) + ' 6 GHz',
		line(legColor[2], 1.5) + line(legColor[2], 5) + ' ' + _('more traffic'),
		line(legColor[2], 2.5, '7 4') + ' ' + _('slow or weak'),
		line('#d9822b', 2.5, '4 3') + ' ' + _('losing beacons'),
		line('#8a939c', 2, '2 5') + ' ' + _('down')
	];
	var key = E('div', { 'style': 'position:absolute;top:8px;right:8px;padding:4px 8px;' +
		'background:rgba(128,128,128,0.14);border:1px solid rgba(128,128,128,0.35);border-radius:6px;' +
		'font-size:10.5px;line-height:17px;opacity:0.9;pointer-events:none',
		'title': _('Hover a line for the numbers and their age') });
	key.innerHTML = rows.map(function(r) { return '<div style="white-space:nowrap">' + r + '</div>'; }).join('');
	return key;
}

function renderNodes(data, amController) {
	var names = data.names || {};
	/* Names that have been typed but not yet confirmed by the box that
	 * carries them. The picture must not present an instruction as a fact:
	 * a name given to a box that was switched off is a promise, and saying
	 * so is the difference between a user who waits and one who types it
	 * again because nothing happened. */
	var pending = data.pending || {};
	var rows = (data.nodes || []).slice().sort(function(a, b) {
		return (a.depth - b.depth) || (a.almac > b.almac ? 1 : -1);
	});

	var table = E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th' }, _('Node')),
			E('th', { 'class': 'th' }, _('Role')),
			E('th', { 'class': 'th' }, _('Depth')),
			E('th', { 'class': 'th' }, _('Backhaul')),
			E('th', { 'class': 'th' }, _('Radios / MLDs')),
			E('th', { 'class': 'th' }, _('Clients')),
			E('th', { 'class': 'th' }, _('Last seen')),
			E('th', { 'class': 'th' }, '')
		])
	]);

	rows.forEach(function(n) {
		var isCtrl = (n.depth === 0);
		/* Same question the picture asks. backhaul_band is a single number -
		 * the primary band - so on an MLO backhaul it names one leg and the
		 * other one silently disappears. The row then read "5 GHz" while the
		 * picture two centimetres above read "MLO · 2 links" about the very
		 * same link, and the second leg (6 GHz) was nowhere. Found 2026-08-26.
		 * bsta_links is what carries the truth, so ask it here too. */
		/* Say which bands the backhaul actually uses. "MLO . 2 links" told us
		 * there were two legs but not which; the band alone told us one leg but
		 * not that there was a second. backhaul_bands carries every leg's band
		 * (from the child's own radios, so it resolves past the first hop too). */
		var bands = (n.backhaul_bands || '').split(',')
			.map(function (b) { return BAND[b]; })
			.filter(function (b) { return b; });
		var bandTxt = bands.length ? bands.join(' + ')
			: (String(n.bh_source || '').indexOf('neighbor') == 0 &&
			   n.media_type != null && n.media_type < 256)
				? _('wired')
			: (BAND[n.backhaul_band] || '?');

		/* Name the box, do not print a BSSID at the user.
		 *
		 * The column used to read "5 GHz -> 42:91:e4:1b:01:3f . 2 hop(s)".
		 * The address is the parent's backhaul BSS and means nothing to a
		 * human; the parent's AL address is right next to it in the same row
		 * and the names map is already loaded for this table. Falls back to
		 * the BSSID when the parent is not a known node.
		 *
		 * "MLO . 2 links" is gone as well: with both bands spelled out, the
		 * count says nothing the bands do not already say. */
		var up = n.backhaul_upstream_al
			? nodeName(names, n.backhaul_upstream_al)
			: (n.upstream_bssid || '?');
		var silent = !isCtrl && n.age_s != null && n.age_s > 180;
		var bh = isCtrl ? _('— (gateway)')
			: silent ? _('offline')
			: !n.backhaul_upstream_al ? _('not placed in the tree')
			: bandTxt + ' → ' + up +
			  (n.wifi_hops ? ' · ' + n.wifi_hops + ' ' + _('hop(s)') : '') +
			  (n.bh_source == 'neighbor' ? ' · ' + _('inferred')
			   : n.bh_source == 'neighbor-mutual' ? ' · ' + _('seen by both')
			   : n.bh_source == 'parent-assoc' ? ' · ' + _('by parent') : '');
		table.appendChild(E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td' }, [ E('strong', {}, nodeName(names, n.almac)),
				pending[n.almac]
					? E('span', {
						'style': 'margin-left:.5em;font-size:.75em;color:#b8860b;white-space:nowrap',
						'title': _('This name is on its way to the box. It is not on the box yet.')
					  }, _('waiting for the box'))
					: E('span', {}),
				/* Renaming lives here, on the mesh, and not in the LuCI of the
				 * box being renamed - that box may be two hops away and the
				 * user has no session on it. This is step five of onboarding
				 * and the only screen it asks for.
				 *
				 * Since 2026-09-26 an inline field, see renameButton(). */
				/* Drawn on every node, because it works on every node. The
				 * table already draws everywhere - it is forwarded from the
				 * controller - and a rename carries the AL-MAC of the node it
				 * names, so it lands on the right box whichever web interface
				 * the user happened to open. Until 2026-09-06 the call was
				 * refused anywhere but the controller while the button was
				 * drawn anyway: reported 2026-08-25 as "renaming does not
				 * work". A control that is visible and refuses is worse than
				 * one that is absent. */
				renameButton(n, names),
				E('div', { 'style': 'color:#888;font-size:.85em' },
					(data.addrs || {})[n.almac] || n.almac),
				(data.addrs || {})[n.almac]
					? E('div', { 'style': 'color:#aaa;font-size:.75em' }, n.almac)
					: E('span', {}) ]),
			E('td', { 'class': 'td' }, isCtrl
				? E('span', { 'style': 'color:#2563b0;font-weight:bold' }, _('controller'))
				: _('agent')),
			E('td', { 'class': 'td' }, !silent && n.depth != null && n.depth >= 0 ? String(n.depth) : '?'),
			E('td', { 'class': 'td' }, bh),
			E('td', { 'class': 'td' }, (n.apmlds_mlo != null && n.apmlds_mlo != n.apmlds)
				? '%d / %d MLO + %d single-link'.format(n.radios || 0, n.apmlds_mlo,
					(n.apmlds || 0) - n.apmlds_mlo)
				: '%d / %d'.format(n.radios || 0, n.apmlds || 0)),
			E('td', { 'class': 'td' }, silent ? '—' : String(n.clients || 0)),
			E('td', { 'class': 'td', 'style': (n.age_s > 180 ? 'color:#c0392b' : '') },
				isCtrl ? '—' : fmtAge(n.age_s)),
			E('td', { 'class': 'td' }, (!isCtrl && n.age_s != null && n.age_s > 180)
				? (function() {
					var x = E('button', { 'class': 'cbi-button cbi-button-remove', 'title': _('Forget this silent node') }, '\u00d7');
					x.addEventListener('click', function() {
						if (!confirm(_('Forget node %s? A node that is really still there will come back within seconds.').format(nodeName(names, n.almac)))) return;
						x.disabled = true;
						callForget(n.almac).then(function() { location.reload(); });
					});
					return x;
				})()
				: '')
		]));
	});

	return table;
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return callState().then(function(st) {
			return Promise.all([ st, callHealth(), callNodes(), callClients(), callTopology(), callAddStatus() ]);
		});
	},

	render: function(data) {
		var st = data[0], health = data[1], nodes = data[2], clients = data[3], topo = data[4], add = data[5];
		/* This screen is where a mesh is opted into, and that is the whole of
		 * its job. EasyMesh ships in every image and lies dormant until someone
		 * asks for it here - so the first thing an owner ever reads about it is
		 * an offer, not a state they have been put in.
		 *
		 * The second path deliberately leads away from this page. Adding a box
		 * to a mesh that already exists needs no screen on the box being added,
		 * which is the entire point of the button, and an invitation to
		 * configure it here would undo that. The gesture is taught at the one
		 * moment it is relevant - while the reader is holding a box they want
		 * to add and looking for what to do with it. */
		if (!st || st.role == 'unconfigured')
			return E('div', { 'style': 'max-width:560px' }, [
				E('h2', {}, _('EasyMesh')),
				E('p', {}, _('This box is not part of a mesh. It does not have to be - everything else about it works the same either way.')),
				E('h3', {}, _('Start a mesh here')),
				E('p', {}, _('Make this the first box: it keeps the network name and password, hands them to every box added later, and stays in charge of the mesh.')),
				E('a', { 'class': 'cbi-button cbi-button-apply', 'href': L.url('admin/network/easymesh/setup') }, _('Set this box up as the first one')),
				E('h3', { 'style': 'margin-top:1.5em' }, _('Adding this box to a mesh you already have?')),
				/* The main box, not any box of the mesh: see the same
				 * sentence in setup.js for why. */
				E('p', {}, _('Then you do not need this screen at all. Leave it plugged in, hold its WPS button for three seconds and let go, then press the WPS button on the main box (the first one you set up). It restarts itself a few times and joins on its own - about four minutes, with nothing to type in. Do not keep holding: ten seconds or more erases the box instead.')),
				E('p', { 'style': 'color:#888;font-size:.9em' }, _('A short press keeps its usual meaning here, so pairing an ordinary device is unaffected.'))
			]);



		var addBox = E('div', {}, [ renderAdd(add) ]);
		GW_AL = (health && health.gateway && health.gateway.almac) || null;
		CLIENTS_BY = clientsByNode(clients);
		var headBox = E('div', {}, renderHeadline(topo, health));
		var healthBox = E('div', {}, renderNow(topo, health, clients));
		var nodesBox = E('div', {}, renderNodes(nodes, st.role == 'controller'));
		var topoBox = E('div', {}, renderTopology(topo, nodes));

		/* Pairing a new box over the air: the controller half of the WPS
		 * join (proven 2026-08-11). One press opens a two-minute window;
		 * the matching press lives on the new box's setup screen. The
		 * countdown is honest - it mirrors hostapd's own PBC timeout. */
		var pairBox = E('div', {});
		if (st.role == 'controller') {
			var pairBtn = E('button', { 'class': 'cbi-button cbi-button-apply' }, _('Pair a new box'));
			var pairStat = E('span', { 'style': 'margin-left:10px;color:#69707a' });
			var pairTimer = null;
			pairBtn.addEventListener('click', function() {
				pairBtn.disabled = true;
				callWpsOpen().then(function(r) {
					if (!(r && r.ok)) {
						pairBtn.disabled = false;
						pairStat.textContent = _('Could not open the window: ') + ((r && r.error) || _('unknown error'));
						return;
					}
					var left = r.window_s || 120;
					pairStat.textContent = _('Window open (%ds) - the new box is exchanging keys now. Watch its setup screen.').format(left);
					if (pairTimer) clearInterval(pairTimer);
					pairTimer = setInterval(function() {
						left -= 1;
						if (left <= 0) {
							clearInterval(pairTimer);
							pairBtn.disabled = false;
							pairStat.textContent = _('Window closed. Press again if the new box was not ready yet.');
							return;
						}
						pairStat.textContent = _('Window open (%ds) - the new box is exchanging keys now. Watch its setup screen.').format(left);
					}, 1000);
				});
			});
			/* What to do next, with the address as the exception rather than
			 * the lead.
			 *
			 * This line used to say only "Address for the new box: X (put it
			 * in its join form)" - which told the reader to go and open the
			 * LuCI of a box that has no address to be reached at yet. That is
			 * the hardest path and the one the button right above exists to
			 * replace, and it disagreed with every other screen in this app,
			 * all of which lead with the button. Worse, the instructions that
			 * DO say to hold the button only appear after the press, so
			 * before it the user was told the wrong thing and after it the
			 * right one.
			 *
			 * The address stays because the cable route genuinely needs it,
			 * and the controller is the only node that can measure which one
			 * is free - the new box is not on the mesh yet to be asked. */
			/* The address used to be the last five words of the paragraph
			 * below, after three sentences about which button to hold and
			 * in what order. It was read as having been removed - the one
			 * fact somebody came to this screen to look up was the hardest
			 * thing on it to find. So it now stands on its own line, above
			 * the instructions rather than buried at the end of them.
			 *
			 * A failed call says so instead of leaving a blank space: an
			 * empty line is indistinguishable from a screen that never had
			 * one, which is exactly the confusion this is fixing. */
			var addrLine = E('div', { 'style': 'margin-top:8px;font-size:13px' },
				_('Looking for a free address…'));
			var stepsLine = E('div', { 'style': 'margin-top:4px;color:#69707a;font-size:12px' },
				_('Press this first, then walk to the new box and hold its WPS button for three seconds - there are seven minutes to get there. The other order works too, but leaves only about three: the new box listens for a shorter while than this one keeps the door open. It joins on its own in about four minutes, with nothing to type in anywhere.'));
			callSuggest().then(function(r) {
				if (r && r.address) {
					dom.content(addrLine, [
						E('span', { 'style': 'color:#69707a' }, _('Next free address: ')),
						E('strong', {}, r.address),
						E('span', { 'style': 'color:#69707a' },
							r.reserved ? _(' (held for a box that had it before)')
							           : _(' - the new box takes this on its own; type it in only if you are setting it up over a cable'))
					]);
				} else {
					/* Say what the controller actually said. suggest_address
					 * refuses for more than one reason - the subnet really
					 * being full, or a node not having reported its address
					 * yet, which is a wait-and-retry and not a fault at all -
					 * and collapsing both into "no free address left" sends
					 * the user looking for a problem that is not there
					 * (measured 2026-09-04: it read as "pairing is broken"
					 * while the mesh was in fact mid-join and fine). */
					addrLine.textContent = (r && r.error)
						? r.error
						: _('The controller did not say which address is free.');
					addrLine.style.color = '#c00';
				}
			}).catch(function() {
				addrLine.textContent = _('Could not ask the controller which address is free.');
				addrLine.style.color = '#c00';
			});
			pairBox = E('div', { 'style': 'margin:10px 0' }, [ pairBtn, pairStat, addrLine, stepsLine ]);
		}

		poll.add(function() {
			return callAddStatus().then(function(a) {
				dom.content(addBox, [ renderAdd(a) ]);
			});
		});

		poll.add(function() {
			return Promise.all([ callHealth(), callNodes(), callClients(), callTopology() ]).then(function(r) {
				GW_AL = (r[0] && r[0].gateway && r[0].gateway.almac) || null;
				CLIENTS_BY = clientsByNode(r[2]);
				dom.content(topoBox, renderTopology(r[3], r[1]));
				dom.content(headBox, renderHeadline(r[3], r[0]));
				dom.content(healthBox, renderNow(r[3], r[0], r[2]));
				if (!EDITING) dom.content(nodesBox, renderNodes(r[1], st.role == 'controller'));
			});
		}, 10);

		return E('div', {}, [
			E('h2', {}, _('EasyMesh')),
			headBox,
			healthBox,
			topoBox,
			st.role == 'controller' ? E('details', { 'style': 'margin:12px 0' }, [
				E('summary', { 'class': 'cbi-button', 'style': 'display:inline-block;cursor:pointer' },
					_('Add a box to the mesh\u2026')),
				E('div', { 'style': 'margin-top:8px' }, [ addBox, pairBox ])
			]) : addBox,
			E('h3', {}, _('Boxes')),
			nodesBox,
			E('div', { 'style': 'margin-top:14px;color:#8a929c;font-size:11px' },
				_('Mesh managed by %s. Data source: controller database via the easymesh API.').format(st.hostname))
		]);
	}
});
