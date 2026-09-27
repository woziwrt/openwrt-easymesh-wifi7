// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

/* Events (2026-09-25): the last 24 hours of the mesh in plain words, newest
 * first - boxes moving between parents, the internet moving between boxes,
 * what the parent planner and the link protection decided, the radio card
 * check. Built by the controller from its own database and log; nothing is
 * collected for this page alone. Text follows the theme colour. */

var callEvents = rpc.declare({ object: 'easymesh', method: 'events' });

var KIND = {
	topology: [ '⇄', _('Topology') ],
	internet: [ '☁', _('Internet') ],
	planner:  [ '⚐', _('Planner') ],
	links:    [ '↔', _('Links') ],
	card:     [ '⚠', _('Radio card') ]
};

function when(ts) {
	var d = new Date(ts * 1000), now = new Date();
	var hm = ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2);
	return d.toDateString() == now.toDateString() ? hm : _('yesterday') + ' ' + hm;
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() { return callEvents(); },

	renderAll: function(r) {
		var ev = ((r && r.events) || []).slice().sort(function(a, b) { return b.ts - a.ts; });
		if (!ev.length)
			return E('p', { 'style': 'opacity:.75' }, _('Nothing happened in the last 24 hours.'));
		return E('div', { 'class': 'table' }, [ E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th', 'style': 'width:7em' }, _('Time')),
			E('th', { 'class': 'th', 'style': 'width:9em' }, _('What')),
			E('th', { 'class': 'th' }, '')
		]) ].concat(ev.slice(0, 150).map(function(e) {
			var k = KIND[e.kind] || [ '•', e.kind ];
			return E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td', 'style': 'white-space:nowrap' }, when(e.ts)),
				E('td', { 'class': 'td', 'style': 'white-space:nowrap;opacity:.8' }, k[0] + ' ' + k[1]),
				E('td', { 'class': 'td' }, e.text)
			]);
		})));
	},

	render: function(data) {
		var self = this, box = E('div', {}, this.renderAll(data));
		poll.add(function() {
			return callEvents().then(function(r) { dom.content(box, self.renderAll(r)); });
		}, 30);
		return E('div', {}, [
			E('h2', {}, _('Events')),
			E('div', { 'class': 'cbi-section-descr' },
				_('What happened in the mesh over the last 24 hours, newest first. Times are this browser\'s local time.')),
			box
		]);
	}
});
