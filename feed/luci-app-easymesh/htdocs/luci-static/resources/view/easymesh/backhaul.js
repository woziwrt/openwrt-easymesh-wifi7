// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

/* Backhaul & MLO (2026-09-25): how each box reaches its parent, leg by leg,
 * and what the controller does with those legs.
 *
 * Every number here comes from the controller: the legs and their beacon
 * share from easymesh-linkstat (what the child hears on its own air), the
 * link rate from the Associated STA Extended Link Metrics the parent reports,
 * and the traffic mapping from the TTLM producer - which may be running as a
 * dry run, and then says what it WOULD do without doing it.
 *
 * Text takes its colour from the theme (light and dark); only small accents
 * carry a colour of their own. */

var callTopology = rpc.declare({ object: 'easymesh', method: 'topology' });
var callTtlm = rpc.declare({ object: 'easymesh', method: 'ttlm_state' });
var callNodes = rpc.declare({ object: 'easymesh', method: 'nodes' });

var BAND = { 1: '2.4 GHz', 2: '5 GHz', 8: '6 GHz' };
var OK = '#2e8540', WARN = '#b58900', BAD = '#c0392b';

var seen = {};
function rate(key, rx, tx, ts) {
	var prev = seen[key];
	if (!ts || isNaN(rx) || isNaN(tx)) return null;
	if (prev && prev.ts == ts) return prev.mbps;
	var mbps = null;
	if (prev && ts > prev.ts && rx >= prev.rx && tx >= prev.tx)
		mbps = ((rx - prev.rx) + (tx - prev.tx)) * 8 / (ts - prev.ts) / 1e6;
	seen[key] = { ts: ts, rx: rx, tx: tx, mbps: mbps };
	return mbps;
}

function legs(almac, detail) {
	return String(detail || '').split(',').filter(function(x) { return x; }).map(function(x) {
		var f = x.split(':');
		return { id: +f[0], state: f[1], band: +f[2],
			beacon: f[3] === '' || f[3] == null ? null : +f[3],
			mbps: rate(almac + '/' + f[0], +f[4], +f[5], +f[6]) };
	});
}

function fmt(m) {
	return m == null ? '—' : m < 1 ? _('quiet') : m < 10 ? m.toFixed(1) + ' Mbit/s' : Math.round(m) + ' Mbit/s';
}

function legCell(g) {
	if (!g) return E('td', { 'class': 'td' }, '—');
	var dead = (g.state != 'up' && g.state != 'degraded');
	var weak = !dead && g.beacon != null && g.beacon < 80;
	var word = dead ? _('down') : weak ? _('weak') : _('up');
	var col = dead ? BAD : weak ? WARN : OK;
	return E('td', { 'class': 'td' }, [
		E('span', { 'style': 'color:' + col + ';font-weight:bold' }, '● ' + word),
		g.beacon != null ? E('span', { 'style': 'opacity:.7' }, ' · ' + _('%d %% beacons').format(g.beacon)) : E([]),
		E('div', { 'style': 'opacity:.7;font-size:11px' }, _('traffic') + ' ' + fmt(g.mbps))
	]);
}

/* A TTLM map "0:2 1:2 ... 7:2" in words: which bands carry the traffic. */
function mapWords(map, lg) {
	var masks = {};
	String(map || '').split(' ').forEach(function(x) {
		var f = x.split(':'); if (f.length == 2) masks[+f[1]] = true;
	});
	var ms = Object.keys(masks).map(Number);
	if (ms.length == 1 && ms[0] == 0) return _('back to both links (teardown)');
	if (ms.length != 1) return _('split by traffic type');
	var bands = lg.filter(function(g) { return ms[0] & (1 << g.id); })
		.map(function(g) { return BAND[g.band] || '?'; });
	return bands.length ? _('all traffic on %s').format(bands.join(' + ')) : _('map %s').format(map);
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return Promise.all([ callTopology(), callTtlm(), callNodes() ]);
	},

	renderAll: function(topo, tt, nodesData) {
		topo = topo || {}; tt = tt || {};
		var names = topo.names || {}, byAl = {}, parentOf = {}, kids = {};
		(topo.nodes || []).forEach(function(n) { byAl[n.almac] = n; });
		(topo.links || []).forEach(function(l) {
			parentOf[l.child_almac] = l.parent_almac;
			(kids[l.parent_almac] = kids[l.parent_almac] || []).push(l.child_almac);
		});
		var ex = {};
		(((nodesData || {}).nodes) || []).forEach(function(n) { ex[n.almac] = n; });
		function nm(al) {
			if (names[al]) return names[al];
			return ex[al] && ex[al].manufacturer ? ex[al].manufacturer + ' · ' + String(al).slice(-5) : al;
		}
		var staOf = {};
		(tt.bsta || []).forEach(function(b) { staOf[b.almac] = b.sta; });
		var strOk = {};
		(tt.str_ok || []).forEach(function(a) { strOk[a] = true; });
		function lineFor(list, sta) {
			return (list || []).filter(function(l) { return l.sta == sta; })[0];
		}

		/* --- the table: one row per backhaul link --- */
		var rows = [ E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th' }, _('Box')),
			E('th', { 'class': 'th' }, _('Parent')),
			E('th', { 'class': 'th' }, '5 GHz'),
			E('th', { 'class': 'th' }, '6 GHz'),
			E('th', { 'class': 'th' }, _('Link rate')),
			E('th', { 'class': 'th' }, _('Relays for')),
			E('th', { 'class': 'th' }, _('Traffic mapping'))
		]) ];
		(topo.nodes || []).slice().sort(function(a, b) { return (a.depth - b.depth) || (a.almac > b.almac ? 1 : -1); })
		.forEach(function(n) {
			if (!parentOf[n.almac]) return;
			var lg = legs(n.almac, n.bsta_link_detail);
			var l5 = lg.filter(function(g) { return g.band == 2; })[0];
			var l6 = lg.filter(function(g) { return g.band == 8; })[0];
			var rel = kids[n.almac] || [];
			var sta = staOf[n.almac];
			var r1 = lineFor(tt.rule1, sta), r2 = lineFor(tt.rule2, sta);
			var ln = r1 || r2, live = r1 ? tt.rule1_live : tt.rule2_live;
			rows.push(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td' }, E('strong', {}, nm(n.almac))),
				E('td', { 'class': 'td' }, nm(parentOf[n.almac])),
				legCell(l5),
				legCell(l6),
				E('td', { 'class': 'td', 'title': _('PHY rate the parent last reported for this backhaul station; about a third of it arrives as TCP.') },
					n.bh_dl_kbps ? _('%d down / %d up').format(Math.round(n.bh_dl_kbps / 1000), Math.round((n.bh_ul_kbps || 0) / 1000)) : '—'),
				E('td', { 'class': 'td' }, rel.length
					? [ rel.map(nm).join(', '),
					    E('div', { 'style': 'font-size:11px;opacity:.75' },
					      strOk[n.almac] ? _('card verified: receives 5 GHz while sending 6 GHz') : _('card not verified for STR')) ]
					: E('span', { 'style': 'opacity:.6' }, _('end of the chain'))),
				E('td', { 'class': 'td' }, ln
					? [ mapWords(ln.map, lg),
					    E('div', { 'style': 'font-size:11px;color:' + (live ? OK : WARN) },
					      live ? _('applied by the controller') : _('dry run - proposed, not applied')) ]
					: _('both links, as the radios choose'))
			]));
		});

		/* --- the two rules, in words --- */
		var reps = (tt.repeaters || []).map(function(r) {
			return E('li', {}, [ E('strong', {}, nm(r.almac)), ': ',
				r.on ? _('bands alternated (parent hop 5 GHz, child hops 6 GHz)')
				     : _('waiting - the children carry less than 5 Mbit/s, so alternating would only cost the box its second link'),
				r.above && !r.on ? ' ' + _('(%d sample(s) above the threshold)').format(r.above) : '' ]);
		});
		function mode(live) {
			return E('span', { 'style': 'font-weight:bold;color:' + (live ? OK : WARN) },
				live ? _('live') : _('dry run'));
		}
		var rules = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('What the controller does with the links')),
			E('p', {}, [ E('strong', {}, _('1. Evade a bad link')), ' — ', mode(tt.rule1_live), E('br'),
				_('When one link keeps losing data (not just beacons), all traffic of that box moves to the healthy link until the bad one has been clean for 4 hours.'),
				E('br'), E('span', { 'style': 'opacity:.75' },
					(tt.rule1 || []).length ? _('%d box(es) affected now.').format(tt.rule1.length) : _('Nothing to evade right now.')) ]),
			E('p', {}, [ E('strong', {}, _('2. Alternate bands across a repeater')), ' — ', mode(tt.rule2_live), E('br'),
				_('A repeater that forwards traffic receives on 5 GHz from its parent and sends on 6 GHz to its children at the same time, instead of sharing one radio both ways. For uploads it is the other way round (receives on 6 GHz, sends on 5 GHz). Measured on 25 Sep for downloads: 153 → 260 Mbit/s through one repeater; the upload direction is not measured yet. Only for cards that passed the STR test.'),
				reps.length ? E('ul', { 'style': 'margin:4px 0 0 18px' }, reps)
				            : E('div', { 'style': 'opacity:.75' }, _('No repeater with a verified card.')) ]),
			E('p', { 'style': 'font-size:11px;opacity:.7' },
				(tt.alive_s != null ? _('Rules last evaluated %d s ago.').format(tt.alive_s) + ' ' : '') +
				_('A dry run only writes down what it would do; switching a rule live is done on the controller.'))
		]);

		return E('div', {}, [
			E('div', { 'class': 'table', 'style': 'margin-bottom:14px' }, rows),
			rules,
			E('div', { 'style': 'margin-top:10px;font-size:11px;opacity:.7' }, [
				_('Beacons: share of the parent\'s beacons the box hears on that link over the last window. A weak link keeps carrying data - lost beacons alone are not a lost link.'),
				E('br'),
				_('STR (simultaneous transmit and receive): the card sends on one band while receiving on the other. On some cards, sending on 5 GHz deafens 6 GHz reception, so such boxes stay at the end of the chain.')
			])
		]);
	},

	render: function(data) {
		var self = this;
		var box = E('div', {}, this.renderAll(data[0], data[1], data[2]));
		poll.add(function() {
			return Promise.all([ callTopology(), callTtlm(), callNodes() ]).then(function(r) {
				dom.content(box, self.renderAll(r[0], r[1], r[2]));
			});
		}, 15);
		return E('div', {}, [
			E('h2', {}, _('Backhaul & MLO')),
			E('div', { 'class': 'cbi-section-descr' },
				_('How each box reaches its parent, link by link, and what the controller does with those links.')),
			box
		]);
	}
});
