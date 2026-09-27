// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';

/* Diagnostics: steering history + expert DB overview. Read-only. */

var callState = rpc.declare({ object: 'easymesh', method: 'node_state' });
var callSteer = rpc.declare({ object: 'easymesh', method: 'steer_history' });
var callDb = rpc.declare({ object: 'easymesh', method: 'db_stats' });
var callDbTable = rpc.declare({
	object: 'easymesh',
	method: 'db_table',
	params: [ 'table', 'limit' ]
});
var callHealth = rpc.declare({ object: 'easymesh', method: 'health' });

var RAW_METHODS = [ 'node_state', 'health', 'topology', 'nodes', 'clients',
	'steer_history', 'db_stats' ];

function rawSection() {
	var wrap = E('div', {});
	RAW_METHODS.forEach(function(m) {
		var pre = E('pre', { 'style': 'font-size:.8em;max-height:340px;overflow:auto;' +
			'background:#f6f6f6;border:1px solid #ddd;border-radius:4px;padding:.6em' },
			_('(expand to load)'));
		var det = E('details', { 'style': 'margin:.3em 0' }, [
			E('summary', { 'style': 'cursor:pointer;font-family:monospace' },
				'ubus call easymesh ' + m),
			pre
		]);
		det.addEventListener('toggle', function() {
			if (!det.open || det.getAttribute('data-loaded')) return;
			det.setAttribute('data-loaded', '1');
			rpc.declare({ object: 'easymesh', method: m })().then(function(r) {
				pre.textContent = JSON.stringify(r, null, 2);
			}, function(e) {
				pre.textContent = _('call failed: %s').format(e);
			});
		});
		wrap.appendChild(det);
	});
	return wrap;
}

function renderSteer(data) {
	/* shape comes straight from map.controller dump_steer_history - be liberal */
	var list = (data && (data.steer_history || data.history || data.entries)) || [];
	if (!Array.isArray(list) && typeof data == 'object' && data && !data.error) {
		Object.keys(data).some(function(k) {
			if (Array.isArray(data[k])) { list = data[k]; return true; }
			return false;
		});
	}
	if (!Array.isArray(list) || !list.length)
		return E('div', { 'class': 'cbi-section-descr' },
			(data && data.error) ? data.error : _('No steering events recorded yet.'));

	var keys = Object.keys(list[0] || {}).slice(0, 7);
	var table = E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr table-titles' }, keys.map(function(k) {
			return E('th', { 'class': 'th' }, k);
		}))
	]);
	list.slice(-20).reverse().forEach(function(row) {
		table.appendChild(E('tr', { 'class': 'tr' }, keys.map(function(k) {
			return E('td', { 'class': 'td' }, String(row[k] != null ? row[k] : '—'));
		})));
	});
	return table;
}

/* Whatever the table holds, drawn as it is stored - no interpretation. */
function renderRows(res) {
	if (res && res.error)
		return E('div', { 'class': 'alert-message warning' }, res.error);

	var rows = (res && res.rows) || [];
	if (!rows.length)
		return E('em', {}, _('no rows'));

	var cols = Object.keys(rows[0]);
	var t = E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr table-titles' }, cols.map(function(c) {
			return E('th', { 'class': 'th' }, c);
		}))
	]);
	rows.forEach(function(r) {
		t.appendChild(E('tr', { 'class': 'tr' }, cols.map(function(c) {
			return E('td', { 'class': 'td', 'style': 'font-size:.85em' },
				String(r[c] != null && r[c] !== '' ? r[c] : '—'));
		})));
	});
	return E('div', { 'style': 'overflow-x:auto' }, t);
}

function renderDb(db) {
	var tables = (db && db.tables) || [];
	var table = E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th' }, _('Table')),
			E('th', { 'class': 'th' }, _('Rows'))
		])
	]);
	tables.forEach(function(t) {
		/* A count says a table is empty; it never says what is in it, and
		 * "why does the controller believe that" is only ever answered by
		 * the rows themselves. They are fetched when opened rather than up
		 * front - the whole database at once is a lot to carry for a page
		 * most readers open to look at one table. */
		var detail = E('div', { 'style': 'display:none;margin:.4em 0 1em 1.5em' });
		var fetched = false;

		var label = t.rows
			? E('a', { 'href': '#', 'click': function(ev) {
				ev.preventDefault();
				var opening = (detail.style.display === 'none');
				detail.style.display = opening ? '' : 'none';
				if (!opening || fetched)
					return;
				fetched = true;
				dom.content(detail, E('em', {}, _('reading…')));
				callDbTable(t.table, 200).then(function(res) {
					dom.content(detail, renderRows(res));
				}, function() {
					fetched = false;
					dom.content(detail, E('div', { 'class': 'alert-message warning' },
						_('Could not read %s.').format(t.table)));
				});
			} }, t.table)
			: t.table;

		table.appendChild(E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td' }, label),
			E('td', { 'class': 'td', 'style': t.rows ? '' : 'color:#b58900' },
				String(t.rows))
		]));
		table.appendChild(E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td', 'colspan': '2' }, detail)
		]));
	});
	return E('div', {}, [
		E('div', { 'class': 'cbi-section-descr' },
			_('Controller DB: %.1f MB, %d tables. Click a table to read it.')
				.format(((db || {}).db_bytes || 0) / 1048576, tables.length)),
		table
	]);
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return callState().then(function(st) {
			return Promise.all([ st, callSteer(), callDb(), callHealth() ]);
		});
	},

	render: function(data) {
		var st = data[0];
		if (!st || st.role == 'unconfigured')
			return E('div', { 'style': 'max-width:520px' }, [
				E('h2', {}, _('EasyMesh')),
				E('p', {}, _('This box is not part of a mesh yet. Set it up first - either as the first box of a new mesh, or by adding it to one you already have.')),
				E('a', { 'class': 'cbi-button cbi-button-apply', 'href': L.url('admin/network/easymesh/setup') }, _('Open the setup'))
			]);


		var steerBox = E('div', {}, renderSteer(data[1]));
		var dbBox = E('div', {}, renderDb(data[2]));

		poll.add(function() {
			return Promise.all([ callSteer(), callDb() ]).then(function(r) {
				dom.content(steerBox, renderSteer(r[0]));
				dom.content(dbBox, renderDb(r[1]));
			});
		}, 30);

		var warn = ((data[3] || {}).warnings || []).filter(function(w) { return w; });

		return E('div', {}, [
			E('h2', {}, _('EasyMesh — Advanced (support)')),
			/* Nobody but the developer reads this page; say so first, so a
			 * user who landed here knows the other tabs are the ones for them. */
			E('div', { 'class': 'cbi-section-descr' },
				_('This page is for troubleshooting when something does not work. You do not need it for everyday use - the other tabs show how the mesh is doing.')),
			warn.length ? E('div', { 'class': 'alert-message warning' },
				warn.map(function(w) { return E('div', {}, w); })) : E([]),
			E('h3', {}, _('Steering history')),
			steerBox,
			E('h3', {}, _('Database (expert)')),
			dbBox,
			E('h3', {}, _('Raw API (expert)')),
			E('div', { 'class': 'cbi-section-descr' },
				_('The whole easymesh dictionary, verbatim.')),
			rawSection()
		]);
	}
});
