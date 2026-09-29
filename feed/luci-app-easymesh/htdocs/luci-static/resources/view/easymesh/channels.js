// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

/* Channels (2026-09-25): which channel each band runs on, and how each box
 * sees it - noise and how busy the channel is - from the AP Metrics every
 * agent reports to the controller (radio table).
 *
 * Noise is the ANPI of the radio: dBm = value / 2 - 110. A box whose noise
 * sits well above the others on the same channel hears its own card, not
 * the air: measured 2026-09-24/25, the two boxes with the noisier cards sit
 * 7-13 dB above the rest, and it follows the box when it is moved.
 * Utilization is 0-255 in the standard; shown in per cent.
 *
 * Channel scans are not collected into the controller yet, so this page
 * does not list neighbouring networks - it says so rather than drawing an
 * empty table. Text follows the theme colour. */

var callTable = rpc.declare({ object: 'easymesh', method: 'db_table', params: [ 'table', 'limit' ] });
var callTopology = rpc.declare({ object: 'easymesh', method: 'topology' });

var BANDS = [ { id: 1, name: '2.4 GHz' }, { id: 2, name: '5 GHz' }, { id: 8, name: '6 GHz' } ];
/* global operating class -> width; channel in the table is the centre */
var WIDTH = { 81: 20, 82: 20, 83: 40, 84: 40, 115: 20, 116: 40, 117: 40, 118: 20, 119: 40, 120: 40,
	121: 20, 122: 40, 123: 40, 124: 20, 125: 20, 126: 40, 127: 40, 128: 80, 129: 160, 130: 80,
	131: 20, 132: 40, 133: 80, 134: 160, 135: 80, 136: 20, 137: 320 };
var WARN = '#b58900', OK = '#2e8540';

function freq(band, ch) {
	return band == 1 ? 2407 + 5 * ch : band == 2 ? 5000 + 5 * ch : 5950 + 5 * ch;
}
function isDfs(band, centre, width) {
	if (band != 2) return false;
	var lo = centre - width / 10 + 2, hi = centre + width / 10 - 2;   /* 20 MHz channel numbers covered */
	return hi >= 52 && lo <= 144;
}
function median(a) {
	var s = a.slice().sort(function(x, y) { return x - y; });
	return s.length ? s[Math.floor(s.length / 2)] : null;
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return Promise.all([ callTable('radio', 200), callTopology() ]);
	},

	renderAll: function(radios, topo) {
		var rows = (radios && radios.rows) || [], names = (topo && topo.names) || {}, live = {};
		(topo && topo.nodes || []).forEach(function(n) { if (n.depth === 0 || n.age_s == null || n.age_s <= 180) live[n.almac] = true; });
		rows = rows.filter(function(r) { return live[r.agent_almac] && r.anpi_noise; });

		var out = [];
		BANDS.forEach(function(b) {
			var rs = rows.filter(function(r) { return r.band == b.id; });
			if (!rs.length) return;
			var first = rs[0], width = WIDTH[first.cur_opclass] || 20;
			var noise = rs.map(function(r) { return r.anpi_noise / 2 - 110; });
			var med = median(noise);
			var dfs = isDfs(b.id, first.channel, width);
			var tr = [ E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('Box')),
				E('th', { 'class': 'th' }, _('Noise')),
				E('th', { 'class': 'th' }, _('Channel busy')),
				E('th', { 'class': 'th' }, '')
			]) ];
			rs.sort(function(x, y) { return (names[x.agent_almac] || '') > (names[y.agent_almac] || '') ? 1 : -1; })
			.forEach(function(r) {
				var n = r.anpi_noise / 2 - 110, over = n - med;
				var busy = Math.round((r.total_utilization || 0) * 100 / 255);
				tr.push(E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td' }, names[r.agent_almac] || r.agent_almac),
					E('td', { 'class': 'td' }, n.toFixed(0) + ' dBm'),
					E('td', { 'class': 'td' }, busy + ' %'),
					E('td', { 'class': 'td' }, over >= 6
						? E('span', { 'style': 'color:' + WARN }, _('%d dB noisier than the other boxes - most likely this box\'s radio card, not the air').format(Math.round(over)))
						: E('span', { 'style': 'opacity:.6' }, ''))
				]));
			});
			out.push(E('div', { 'class': 'cbi-section' }, [
				/* The table holds the centre channel for 5 and 6 GHz; people
				 * know the channels a width covers (36-48), not its centre. */
				E('h3', {}, b.name + ' — ' + (b.id != 1 && width > 20
					? _('channels %d–%d (%d MHz)').format(first.channel - (width / 10 - 2), first.channel + (width / 10 - 2), width)
					: _('channel %d (%d MHz)').format(first.channel, width)) +
					(dfs ? ' · ' + _('radar channel (DFS)') : '')),
				E('div', { 'class': 'table' }, tr)
			]));
		});

		out.push(E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Should the mesh change channel?')),
			E('p', {}, _('Every box of the mesh has to use the same channel in each band - a backhaul link needs both ends on one channel. So a change is always a change for the whole mesh.')),
			E('p', {}, [ E('strong', {}, _('5 GHz: ')),
				_('in one test on 23 Sep (each channel measured once, one after the other, so not yet a settled result) channel 100 carried 43 % more than channel 36 over all links, and one backhaul link went from 79 to 793 Mbit/s. But channel 100 needs radar detection (DFS): after radar the whole mesh has to leave it, listen for 60 s on the new channel and may not come back for 30 min. These radio cards cannot watch for radar in the background, so there is no ready spare channel. The mesh therefore stays on channel 36, which never has to stop for radar.') ]),
			E('p', { 'style': 'opacity:.75' }, _('Neighbouring networks per channel are not shown yet: the controller does not collect channel scans. A channel suggestion based on them will come once it does.'))
		]));
		return out;
	},

	render: function(data) {
		var self = this;
		var box = E('div', {}, this.renderAll(data[0], data[1]));
		poll.add(function() {
			return Promise.all([ callTable('radio', 200), callTopology() ]).then(function(r) {
				dom.content(box, self.renderAll(r[0], r[1]));
			});
		}, 30);
		return E('div', {}, [
			E('h2', {}, _('Channels')),
			E('div', { 'class': 'cbi-section-descr' },
				_('Which channel each band uses, and how every box hears it: noise and how busy the channel is. Reported by the boxes themselves.')),
			box
		]);
	}
});
