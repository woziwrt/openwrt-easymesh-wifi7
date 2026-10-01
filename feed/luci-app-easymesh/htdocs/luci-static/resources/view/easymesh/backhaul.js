// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require rpc';
'require poll';
'require dom';
'require ui';

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
var callPlan = rpc.declare({ object: 'easymesh', method: 'parent_plan' });
var callPlanSet = rpc.declare({ object: 'easymesh', method: 'parent_plan_set', params: [ 'live' ] });
var refreshNow = function() {};
var callMoveOptions = rpc.declare({ object: 'easymesh', method: 'move_options', params: [ 'almac' ] });
var callManualMove = rpc.declare({ object: 'easymesh', method: 'manual_move', params: [ 'almac', 'parent' ] });

/* "Move..." - put a box under another parent by hand. It is the same
 * measured trial the planner runs: throughput before and after, kept only
 * if it is faster, otherwise the box goes back by itself. The dialog says
 * plainly what it costs, since a move takes the box and every box behind
 * it off the mesh for a moment - and for longer if the new place does not
 * answer. */
function moveDialog(almac, nm) {
	var body = E('div', {}, E('p', { 'class': 'spinning' }, _('Asking which parents this box can hear…')));
	ui.showModal(_('Move %s').format(nm(almac)), [ body,
		E('div', { 'class': 'right' }, E('button', { 'class': 'cbi-button', 'click': ui.hideModal }, _('Close'))) ]);
	callMoveOptions(almac).then(function(r) {
		var opts = (r && r.options) || [];
		if (r && r.trial_running) {
			dom.content(body, E('p', {}, _('Another move is being tried right now. Try again in a few minutes.')));
			return;
		}
		if (!opts.length) {
			dom.content(body, E('p', {}, _('This box has not heard any other parent in its last scan (it scans every 10 minutes).')));
			return;
		}
		function sig(o) {
			return [ o.s5 != null ? '5 GHz ' + o.s5 + ' dBm' : null, o.s6 != null ? '6 GHz ' + o.s6 + ' dBm' : null ]
				.filter(function(x) { return x; }).join(' · ');
		}
		var list = E('div', {});
		opts.sort(function(a, b) { return (b.s5 || -200) - (a.s5 || -200); }).forEach(function(o) {
			var why = o.current ? _('it is there now') : (o.below ? _('it is below this box - it would cut itself off') : '');
			var b = E('button', { 'class': 'cbi-button cbi-button-action', 'style': 'min-width:14em;text-align:left', 'disabled': why ? '' : null },
				nm(o.almac));
			b.addEventListener('click', function() {
				dom.content(body, E('p', { 'class': 'spinning' }, _('Starting the trial…')));
				callManualMove(almac, o.almac).then(function(res) {
					if (!res || !res.started) {
						dom.content(body, E('p', {}, _('Not started: %s').format((res && res.error) || _('no answer'))));
						return;
					}
					dom.content(body, [ E('p', {}, _('Trying %s under %s. It measures for about three minutes, then keeps the move only if it is faster, or goes back by itself. The result appears under "Last trials" below and in Events.').format(nm(almac), nm(o.almac))),
						E('p', {}, _('You can close this window.')) ]);
					refreshNow();
				}, function(err) { dom.content(body, E('p', {}, _('Not started: %s').format(err))); });
			});
			list.appendChild(E('div', { 'style': 'margin:6px 0' }, [ b, ' ', E('span', { 'style': 'opacity:.75' }, why || sig(o)) ]));
		});
		dom.content(body, [
			E('p', {}, _('Put it under:')),
			list,
			E('p', { 'style': 'margin-top:12px;font-size:12px;opacity:.8' },
				_('A move takes this box and every box behind it off the mesh for a few seconds. If the new parent does not answer, they are off for one to three minutes before the box goes back by itself. While it measures, about three minutes of test traffic run on this branch.'))
		]);
	});
}

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
		return Promise.all([ callTopology(), callTtlm(), callNodes(), callPlan() ]);
	},

	renderAll: function(topo, tt, nodesData, plan) {
		topo = topo || {}; tt = tt || {}; plan = plan || {};
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
				E('td', { 'class': 'td' }, [ nm(parentOf[n.almac]), ' ',
					E('button', { 'class': 'cbi-button', 'style': 'padding:0 6px;font-size:11px',
						'click': function() { moveDialog(n.almac, nm); } }, _('Move…')) ]),
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
		/* --- 3. choosing the parent: what the planner thinks of each box --- */
		function macs(txt) {
			return String(txt || '').replace(/([0-9a-f]{2}:){5}[0-9a-f]{2}/g, function(m) { return nm(m); });
		}
		function planWords(p) {
			var l = p.line || '', m;
			if (plan.running && plan.running == p.almac)
				return _('a measured trial is running now');
			switch (p.state) {
			case 'keep':
				return _('stays - no clearly better parent');
			case 'wait':
				m = l.match(/->\s+([0-9a-f:]{17}).*?([+-]\d+) %.*?seen (\d+)\/(\d+)/);
				return m ? _('would move under %s (%s %%), confirming (%s of %s checks)').format(nm(m[1]), m[2], m[3], m[4]) : macs(l);
			case 'MOVE':
				m = l.match(/->\s+([0-9a-f:]{17})/);
				return m ? _('about to be tried under %s').format(nm(m[1])) : macs(l);
			case 'hold':
				return _('resting after a trial');
			case 'settling':
				return _('settling after a change of parent');
			case 'no action':
				return /not heard/.test(l) ? _('not reachable over the mesh right now - it moves by itself if its link is unusable')
				                           : _('waiting for a parent in range');
			}
			return macs(l);
		}
		function planSection() {
			var items = (plan.nodes || []).map(function(p) {
				return E('li', {}, [ E('strong', {}, nm(p.almac)), ': ', planWords(p) ]);
			});
			var trials = (plan.trials || []).slice().reverse().map(function(t) {
				var when = new Date(t.ts * 1000);
				var hm = ('0' + when.getHours()).slice(-2) + ':' + ('0' + when.getMinutes()).slice(-2);
				var num = (t.base && t.base.length == 2 && t.trial && t.trial.length == 2)
					? ' - ' + _('%d/%d → %d/%d Mbit/s (up/down)').format(t.base[0], t.base[1], t.trial[0], t.trial[1]) : '';
				var v = { 'kept': _('kept'), 'reverted': _('went back, it did not pay'),
				          'target-unreachable': _('could not get there, went back'),
				          'no-baseline': _('could not measure first, not tried'),
				          'timeout': _('no answer from the box, given up') }[t.verdict] || t.verdict;
				return E('li', {}, [ hm, ' ', E('strong', {}, nm(t.child)), ' → ', nm(t.parent), ': ', v, num ]);
			});
			/* the planner reports every 5 min; a file much older than that is a planner that stopped */
			var stale = (plan.age_s != null && plan.age_s > 900)
				? E('div', { 'style': 'font-weight:bold;color:' + WARN },
				    _('The planner has not reported for %d min - what follows is old.').format(Math.floor(plan.age_s / 60))) : '';
			/* the switch: off by default, since every move costs the box and
			 * the boxes behind it a few seconds and a minute of measuring.
			 * Since 2026-10-01 it covers the tidy-up (rule B) only; the
			 * rescue of a box on a bad path (rule A) runs by default. */
			var sw = E('button', { 'class': 'cbi-button', 'style': 'margin-left:8px' },
				plan.live ? _('Switch off') : _('Switch on'));
			sw.addEventListener('click', function() {
				sw.disabled = true;
				callPlanSet(!plan.live).then(function() { refreshNow(); }, function() { sw.disabled = false; });
			});
			/* a danger zone, as the word is used elsewhere: a switch that
			 * trades moments of connectivity for faster paths */
			var danger = E('div', { 'style': 'border:1px solid ' + BAD + ';border-radius:6px;padding:8px 12px;margin:6px 0 8px;max-width:760px' }, [
				E('strong', { 'style': 'color:' + BAD }, _('Danger zone')), ' — ', _('moves towards the main box'), sw, E('br'),
				E('span', {}, plan.live
					? _('On: besides rescuing a box on a bad path, the planner also moves a box to a parent closer to the main box when that is clearly better. Each move takes that box and every box behind it off the mesh for a few seconds (one to three minutes if the new parent does not answer), and measuring runs about three minutes of test traffic.')
					: _('Off (default): only a box on a path under about 100 Mbit/s is moved - the rescue below. Nothing is moved for speed alone.')),
				E('br'), E('span', { 'style': 'font-size:12px;color:' + WARN },
					_('Switching it off does not undo the moves it made - put a box back with "Move…" in the table above.'))
			]);
			return E('p', {}, [ E('strong', {}, _('3. Choosing the parent')), ' — ',
				E('span', { 'style': 'font-weight:bold;color:' + (plan.rescue !== false ? OK : WARN) },
					plan.rescue !== false ? _('rescue on') : _('rescue off')),
				', ', _('towards the main box:'), ' ', mode(plan.live), E('br'),
				danger,
				_('Rescue (on by default): a box whose path is bad (under about 100 Mbit/s) is moved when another parent is at least twice as good. With the danger zone on, a box is also moved when a parent one hop closer to the main box is at least 1.5 times as good. Every move is a measured trial: throughput before and after, and a move that does not pay is undone.'),
				stale,
				items.length ? E('ul', { 'style': 'margin:4px 0 0 18px' }, items)
				             : E('div', { 'style': 'opacity:.75' }, _('The planner has not reported yet.')),
				trials.length ? E('div', { 'style': 'margin-top:6px' }, _('Last trials:')) : '',
				trials.length ? E('ul', { 'style': 'margin:2px 0 0 18px' }, trials) : '' ]);
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
			planSection(),
			E('p', { 'style': 'font-size:11px;opacity:.7' },
				(tt.alive_s != null ? _('Rules last evaluated %d s ago.').format(tt.alive_s) + ' ' : '') +
				_('A dry run only writes down what it would do. Rules 1 and 2 are switched live on the controller; the planner in its danger zone above.'))
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
		var box = E('div', {}, this.renderAll(data[0], data[1], data[2], data[3]));
		refreshNow = function() {
			return Promise.all([ callTopology(), callTtlm(), callNodes(), callPlan() ]).then(function(r) {
				dom.content(box, self.renderAll(r[0], r[1], r[2], r[3]));
			});
		};
		poll.add(refreshNow, 15);
		return E('div', {}, [
			E('h2', {}, _('Backhaul & MLO')),
			E('div', { 'class': 'cbi-section-descr' },
				_('How each box reaches its parent, link by link, and what the controller does with those links.')),
			box
		]);
	}
});
