// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

/* Nodes (2026-09-25): one card per box - where it sits in the mesh, how it
 * reaches its parent, whom it relays for, and whether its radio card is one
 * of the noisy ones.
 *
 * Read-only on purpose. Moving a box to another parent from here is planned
 * (with an automatic return when the new place turns out worse), but it
 * changes the topology and is tested on the lab first.
 *
 * Everything comes from the controller: topology and link legs as on the
 * Backhaul page, the internet exit from health, the card verdict from
 * easymesh-card-check (median noise over the last hour against the other
 * boxes on the same channel) and the STR list from the TTLM producer. Text
 * takes its colour from the theme; only small accents carry their own. */

var callTopology = rpc.declare({ object: 'easymesh', method: 'topology' });
var callNodes = rpc.declare({ object: 'easymesh', method: 'nodes' });
var callTtlm = rpc.declare({ object: 'easymesh', method: 'ttlm_state' });
var callHealth = rpc.declare({ object: 'easymesh', method: 'health' });

var BAND = { 1: '2.4 GHz', 2: '5 GHz', 8: '6 GHz' };
var OK = '#2e8540', WARN = '#b58900', BAD = '#c0392b', IDLE = '#8a939c';

function dot(col, word) {
	return E('span', { 'style': 'color:' + col + ';font-weight:bold' }, '● ' + word);
}

function ago(s) {
	if (s == null || s < 0) return _('just now');
	if (s < 90) return _('%d s ago').format(s);
	if (s < 5400) return _('%d min ago').format(Math.round(s / 60));
	return _('%d h ago').format(Math.round(s / 3600));
}

function legs(detail) {
	return String(detail || '').split(',').filter(function(x) { return x; }).map(function(x) {
		var f = x.split(':');
		return { id: +f[0], state: f[1], band: +f[2],
			beacon: f[3] === '' || f[3] == null ? null : +f[3] };
	});
}

function legWords(g) {
	var dead = (g.state != 'up' && g.state != 'degraded');
	var weak = !dead && g.beacon != null && g.beacon < 80;
	return E('span', { 'style': 'margin-right:14px' }, [
		(BAND[g.band] || '?') + ' ',
		dot(dead ? BAD : weak ? WARN : OK, dead ? _('down') : weak ? _('weak') : _('up')),
		g.beacon != null ? E('span', { 'style': 'opacity:.7' }, ' ' + _('(%d %% beacons)').format(g.beacon)) : E([])
	]);
}

function row(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td', 'style': 'width:170px;opacity:.75;vertical-align:top' }, label),
		E('td', { 'class': 'td' }, value)
	]);
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return Promise.all([ callTopology(), callNodes(), callTtlm(), callHealth() ]);
	},

	renderAll: function(topo, nodesData, tt, health) {
		topo = topo || {}; tt = tt || {}; health = health || {};
		var names = topo.names || {}, addrs = topo.addrs || {};
		var parentOf = {}, linkOf = {}, kids = {}, ex = {}, strOk = {}, suspect = {}, judged = {};
		(topo.links || []).forEach(function(l) {
			parentOf[l.child_almac] = l.parent_almac;
			linkOf[l.child_almac] = l;
			(kids[l.parent_almac] = kids[l.parent_almac] || []).push(l.child_almac);
		});
		(((nodesData || {}).nodes) || []).forEach(function(n) { ex[n.almac] = n; });
		(tt.str_ok || []).forEach(function(a) { strOk[a] = true; });
		(tt.card_suspect || []).forEach(function(c) { (suspect[c.almac] = suspect[c.almac] || []).push(c); });
		(tt.card_judged || []).forEach(function(a) { judged[a] = true; });
		var gw = (health.gateway || {}).almac;

		function nm(al) {
			if (names[al]) return names[al];
			return ex[al] && ex[al].manufacturer ? ex[al].manufacturer + ' · ' + String(al).slice(-5) : al;
		}

		var nodes = (topo.nodes || []).slice().sort(function(a, b) {
			return (a.depth - b.depth) || (nm(a.almac) > nm(b.almac) ? 1 : -1);
		});
		if (!nodes.length)
			return [ E('p', {}, _('No boxes known yet.')) ];

		return nodes.map(function(n) {
			var x = ex[n.almac] || {}, main = n.depth === 0;
			var age = main ? null : (n.age_s != null ? n.age_s : x.age_s);
			var silent = !main && age != null && age > 180;
			var rows = [];

			rows.push(row(_('Address'), addrs[n.almac] || '—'));

			/* place in the mesh */
			if (main)
				rows.push(row(_('Place in the mesh'), _('main box - it runs the mesh')));
			else {
				var hops = n.wifi_hops || n.depth;
				rows.push(row(_('Place in the mesh'), [
					hops == 1 ? _('1 hop from the main box') : _('%d hops from the main box').format(hops),
					' · ' + _('parent') + ': ', E('strong', {}, nm(parentOf[n.almac] || n.backhaul_upstream_al) || '?')
				]));
			}

			/* how it reaches its parent */
			if (!main) {
				var l = linkOf[n.almac] || {}, mt = l.media_type != null ? l.media_type : n.media_type;
				var lg = legs(n.bsta_link_detail);
				var v;
				if (mt != null && mt < 256)
					v = _('cable');
				else if (lg.length)
					v = E('span', {}, lg.map(legWords));
				else
					v = n.backhaul_bands
						? _('Wi-Fi %s').format(String(n.backhaul_bands).split(',').map(function(b) { return BAND[b] || b; }).join(' + '))
						: _('Wi-Fi');
				rows.push(row(_('Link to parent'), v));
				if (n.bh_dl_kbps || n.bh_ul_kbps)
					rows.push(row(_('Link rate'), E('span', {
						'title': _('PHY rate the parent last reported for this box\'s backhaul station; roughly a third of it arrives as TCP.') },
						_('%d Mbit/s down · %d Mbit/s up').format(Math.round((n.bh_dl_kbps || 0) / 1000), Math.round((n.bh_ul_kbps || 0) / 1000)))));
			}

			/* whom it relays for */
			var k = (kids[n.almac] || []).map(nm).sort();
			rows.push(row(_('Relays for'), k.length ? k.join(', ') : _('no boxes below it')));

			rows.push(row(_('Wi-Fi clients'), String(x.clients != null ? x.clients : 0)));

			if (main && gw)
				rows.push(row(_('Internet'), gw == n.almac ? _('goes out through this box') : _('goes out through %s').format(nm(gw))));
			else if (gw == n.almac)
				rows.push(row(_('Internet'), _('goes out through this box')));

			/* the radio card */
			var sus = suspect[n.almac] || [];
			var card = [];
			if (sus.length) {
				card.push(dot(WARN, _('noisy')), ' ',
					sus.map(function(c) { return _('%s +%s dB').format(BAND[c.band] || '?', Number(c.excess_db).toFixed(1)); }).join(', '),
					E('div', { 'style': 'opacity:.75;font-size:12px' },
						_('It hears more noise than the other boxes on the same channel - most likely its own radio card, not the air. Such a box does best at the end of a chain; slow links to it are the card, not the mesh.')));
			}
			else if (judged[n.almac])
				card.push(dot(OK, _('normal')));
			else
				card.push(dot(IDLE, _('still measuring')), ' ',
					E('span', { 'style': 'opacity:.75;font-size:12px' },
						_('- the check compares its noise with the other boxes over about half an hour; a box that joined or restarted recently has no verdict yet.')));
			if (strOk[n.almac])
				card.push(E('div', { 'style': 'opacity:.75;font-size:12px' },
					_('Tested: it receives on 5 GHz while it sends on 6 GHz (the other direction is not tested yet).')));
			rows.push(row(_('Radio card'), card));

			var head = [ nm(n.almac), ' ' ];
			head.push(E('span', { 'style': 'font-size:12px;font-weight:normal;margin-left:6px' },
				silent ? dot(BAD, _('not responding · last heard %s').format(ago(age)))
				       : dot(OK, main ? _('online') : _('online · heard %s').format(ago(age)))));

			return E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, head),
				E('table', { 'class': 'table' }, rows)
			]);
		}).concat([
			E('p', { 'style': 'opacity:.75' },
				_('A box picks its parent when it joins, and the mesh keeps it there. Choosing a better parent, and moving a box by hand with an automatic way back, will come to this page.'))
		]);
	},

	render: function(data) {
		var self = this;
		var box = E('div', {}, this.renderAll(data[0], data[1], data[2], data[3]));
		poll.add(function() {
			return Promise.all([ callTopology(), callNodes(), callTtlm(), callHealth() ]).then(function(r) {
				dom.content(box, self.renderAll(r[0], r[1], r[2], r[3]));
			});
		}, 30);
		return E('div', {}, [
			E('h2', {}, _('Nodes')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Every box of the mesh: where it sits, how it reaches its parent, whom it relays for, and whether its radio card is one of the noisy ones.')),
			box
		]);
	}
});
