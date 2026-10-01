// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
'use strict';
'require view';
'require ui';
'require rpc';
'require poll';
'require dom';

/* The setup screen, and why it is shaped like this.
 *
 * Founding a mesh and joining one are not two variants of a form - they are
 * different acts. Founding is configuration: the user decides what the network
 * is called and what its password is, and the node becomes the root. Joining is
 * authorisation: everything already exists, and a node told the network name
 * again is a node that can be told it wrongly, leaving two networks with one
 * name and two keys - a fault nobody ever finds. So the joining screen asks for
 * nothing but a name for the box.
 *
 * The backhaul is never shown. Its name and key are the wiring between the
 * boxes; a user who can type them can only get them wrong, and would never need
 * to read them back.
 */

var callState = rpc.declare({ object: 'easymesh', method: 'setup_state' });
var callFound = rpc.declare({
	object: 'easymesh', method: 'setup_controller',
	params: [ 'ssid', 'wifi_key', 'root_password', 'address', 'hostname', 'backhaul_key' ]
});
var callJoin = rpc.declare({
	object: 'easymesh', method: 'setup_agent',
	params: [ 'hostname', 'gateway' ]
});
var callWpsJoin = rpc.declare({
	object: 'easymesh', method: 'wps_join',
	params: [ 'hostname', 'gateway', 'address' ]
});
var callWpsStatus = rpc.declare({ object: 'easymesh', method: 'wps_status' });
var callCreds = rpc.declare({ object: 'easymesh', method: 'credentials' });
var callSetCreds = rpc.declare({
	object: 'easymesh', method: 'set_credentials',
	params: [ 'ssid', 'wifi_key' ]
});

function row(label, hint, widget) {
	return E('div', { 'style': 'margin-bottom:14px' }, [
		E('label', { 'style': 'display:block;font-weight:600;margin-bottom:3px' }, label),
		widget,
		hint ? E('div', { 'style': 'font-size:11px;color:#69707a;margin-top:3px' }, hint) : ''
	]);
}

function input(id, type, placeholder, value) {
	return E('input', {
		'id': id, 'type': type || 'text', 'placeholder': placeholder || '',
		'value': value || '',
		'style': 'width:100%;max-width:360px;padding:5px'
	});
}


/* Passwords get an eye. Half of them arrive here by copy-paste from a
 * file, and a paste you cannot verify is a mesh debugging session later. */
function pwinput(id, value) {
	var inp = E('input', { 'id': id, 'type': 'password', 'value': value || '',
		'style': 'width:100%;max-width:320px;padding:5px' });
	var eye = E('button', { 'type': 'button', 'class': 'cbi-button',
		'style': 'margin-left:6px;padding:5px 8px' }, '\ud83d\udc41');
	eye.addEventListener('click', function(ev) {
		ev.preventDefault();
		inp.type = (inp.type == 'password') ? 'text' : 'password';
	});
	return E('div', { 'style': 'display:flex;align-items:center;max-width:360px' }, [ inp, eye ]);
}

function val(id) {
	var e = document.getElementById(id);
	return e ? e.value : '';
}

function note(text, kind) {
	var bg = kind == 'bad' ? '#f8d7da' : (kind == 'good' ? '#d4edda' : '#fff3cd');
	return E('div', {
		'style': 'background:' + bg + ';border-radius:6px;padding:10px 12px;margin:12px 0;color:#24292f'
	}, text);
}


/* The reboot screen.
 *
 * Pressing "Reboot now" used to leave the wizard exactly as it was: the browser
 * had nothing left to talk to, so the last sentence sat there unchanged while
 * the box went down and came back. Users read that as a freeze and start poking
 * at a box that is in the middle of booting.
 *
 * So the page gets covered by one sentence and a spinner, and the browser waits
 * for the box itself. The service socket keeps 192.168.1.1 through the whole
 * setup - founding moves the address from br-lan to lan3 but never changes it -
 * so whatever address the user is on is the address that comes back, and the
 * wait can simply poll where it already is. That only holds while the cable
 * stays in LAN3, which is why the timeout says so.
 *
 * Where it lets go matters as much as that it waits. A reboot the user asked
 * for is finished business and belongs at the login screen; a reboot the join
 * takes in the middle of its own work is not, and dropping the user at LuCI's
 * front door there loses a story that is still running. So the caller says
 * where the wait ends, and what to promise while it lasts.
 *
 * Founding is the exception to "the address that comes back". The README
 * sends the user to a LAN port, not the service port, and after the reboot
 * that port is in the mesh: the computer gets an address from the new mesh
 * and the main box answers at the mesh address it was just given, not at
 * 192.168.1.1. So founding passes `hosts` - the new address first, the one
 * the page came from second - and the wait goes to whichever answers.
 */
function rebootOverlay(dest, hintText, waitDown, hosts) {
	document.head.appendChild(E('style', {},
		'@keyframes em-spin { to { transform: rotate(360deg) } }'));

	var spinner = E('div', { 'style':
		'width:38px;height:38px;margin:0 auto 18px;border-radius:50%;' +
		'border:4px solid #d0d7de;border-top-color:#0969da;' +
		'animation:em-spin 1s linear infinite' });

	var hint = E('div', { 'style': 'font-size:13px;color:#69707a;margin-top:10px' },
		hintText || _('This takes a minute or two. The login screen comes back on its own.'));

	document.body.appendChild(E('div', { 'style':
		'position:fixed;top:0;left:0;right:0;bottom:0;z-index:9999;background:#fff;' +
		'display:flex;align-items:center;justify-content:center;text-align:center' },
		E('div', {}, [
			spinner,
			/* waitDown is the join's own wait, and since 2026-09-20 the
			 * join does not reboot unless its fallback needs to - so it
			 * must not be headed "restarting". */
			E('div', { 'style': 'font-size:17px;color:#24292f' },
				waitDown ? _('Please wait…') : _('Router restarting…')),
			hint
		])));

	/* The box answers for a few seconds after it accepts the reboot, so asking
	 * straight away finds the machine on its way down and the screen would be
	 * gone before the reboot even started.
	 *
	 * A delay only covers a reboot the user just asked for. The join's own
	 * restarts arrive on someone else's clock: bh-key-adopt sleeps its full
	 * 30 s interval before it looks at anything, so the box is still serving
	 * twenty seconds after "joined" is posted. Letting go there drops the user
	 * on a login screen that dies under them ten seconds later - the same
	 * stopped page, moved. So for those, watch the box LEAVE first and only
	 * then wait for it to come back. If it never seems to leave - a reboot
	 * that slips between two probes - give up on that after three minutes and
	 * let go anyway, because a page that waits forever is the thing we came to
	 * fix. */
	var deadline = Date.now() + 300000;
	var home = dest || (window.location.origin + '/cgi-bin/luci/');
	var sawItLeave = !waitDown;
	var stopWaitingForIt = Date.now() + 180000;

	/* Waiting on a state has one failure mode a restart counter does not: a
	 * box that keeps answering "working" keeps earning another round, and the
	 * page waits forever - the very thing this overlay exists to prevent.
	 * Measured 2026-08-15: a node whose adoption fuse had blown reported
	 * working long enough that the spinner never stopped and had to be
	 * reloaded by hand. So every round still gets its own clock, but none of
	 * them may push past this one. */
	var hardStop = Date.now() + 900000;

	/* fetch has no timeout, and the whole loop is rescheduled from inside the
	 * promise - so one request that neither answers nor fails takes the
	 * spinner with it, for as long as the operating system is willing to wait
	 * on the socket. That is not hypothetical: measured 2026-08-14, the first
	 * of the two join restarts hung there every time and the second never did.
	 * The difference is when the box leaves. After "joined" it serves for
	 * another thirty seconds, so probes come and go cleanly and the one that
	 * finds it gone is refused outright. After "preparing the radio" it leaves
	 * three seconds later - right under the first probe, mid-request, which is
	 * the one case that hangs instead of failing.
	 *
	 * So every probe gets its own deadline, and a probe that runs out is read
	 * as "not back yet", which is exactly what it means. */
	function probeOnce() {
		var ctl = ('AbortController' in window) ? new AbortController() : null;
		var timer = ctl ? window.setTimeout(function() { ctl.abort(); }, 4000) : null;
		function done(up) { if (timer) window.clearTimeout(timer); return up; }
		return fetch(home, { method: 'HEAD', cache: 'no-store',
				signal: ctl ? ctl.signal : undefined })
			.then(function() { return done(true); }, function() { return done(false); });
	}

	/* With several hosts, ask the way LuCI's own reboot page does
	 * (ui.pingDevice: an image from LuCI's static files). fetch cannot
	 * look at another origin without CORS headers uhttpd does not send;
	 * an image can, and only a LuCI has that file. The first host in the
	 * list wins when more than one answers. */
	function probeHosts() {
		return Promise.all(hosts.map(function(h) {
			return ui.pingDevice('http', h).then(function() { return h; }, function() { return null; });
		})).then(function(up) {
			for (var i = 0; i < up.length; i++)
				if (up[i]) { home = 'http://' + up[i] + '/cgi-bin/luci/'; return true; }
			return false;
		});
	}

	/* "It answers again" is not "it is done".
	 *
	 * Measured 2026-08-15 on a from-scratch BPI-R4 Pro 8X join: an over-the-air join
	 * takes THREE restarts - role, join, and bh-key-adopt's finisher - and the
	 * wizard only ever narrated two. Between the second and the third the login
	 * screen is back, so the user signs in, starts working, and the box
	 * disappears under their hands. Outwardly that reads as a dead router, not
	 * as progress, and it is the moment they reach for the console.
	 *
	 * So the overlay stops counting restarts and waits on a state instead:
	 * bh-key-adopt publishes one word at /easymesh-state, readable without a
	 * session because at this moment there is none. Waiting on the state
	 * survives however many restarts a join really takes - three today, fewer
	 * when the finisher has nothing to raise, and whatever a later change makes
	 * it - without this file having to know the number.
	 *
	 * It asks over the same null rpcd session the narrator uses, for the same
	 * reason: at this moment there is no sysauth session and the answer must
	 * not stop at a login wall. A box that reports nothing is a box that never
	 * runs the finisher - the controller's own setup, or an older build - so a
	 * missing field means done. Anything else and a page that waits forever is
	 * back, which is the thing this spinner was written to stop being. */
	var ubusUrl;
	try { ubusUrl = new URL(home).origin + '/ubus'; }
	catch (e) { ubusUrl = '/ubus'; }

	function askState() {
		/* Only founding passes hosts, and a founded controller never runs
		 * the finisher (setup_controller clears adopt-state). A POST to
		 * the new address would be refused as cross-origin anyway. */
		if (hosts) return Promise.resolve('');
		var ctl = ('AbortController' in window) ? new AbortController() : null;
		var timer = ctl ? window.setTimeout(function() { ctl.abort(); }, 4000) : null;
		function done(v) { if (timer) window.clearTimeout(timer); return v; }
		return fetch(ubusUrl, {
				method: 'POST', cache: 'no-store',
				headers: { 'Content-Type': 'application/json' },
				signal: ctl ? ctl.signal : undefined,
				body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'call',
					params: [ '00000000000000000000000000000000',
						  'easymesh', 'setup_state', {} ] })
			})
			.then(function(r) { return r.json(); })
			.then(function(j) {
				var st = (j.result && j.result[1]) || null;
				return done(st && st.adopt_state ? String(st.adopt_state) : '');
			}, function() { return done(''); });
	}

	function giveUp() {
		/* Name the thing the user can actually check. On the wired path that
		 * is the cable; on a join over the air the cable is not involved at
		 * all, and the old wording sent people to look at a socket that had
		 * nothing to do with it - and named LAN3, which is not what the port
		 * is called on every board.
		 *
		 * After founding, the service port is the wrong thing to name: the
		 * user was sent to a LAN port, and there the box now answers at its
		 * new address. Name that first, and the old one for the case where
		 * the cable is in the service port after all. */
		dom.content(hint, waitDown
			? _('Still not back. Sign in and open Network - EasyMesh to see where it stopped.')
			: (hosts
				? _('Still not back. Open http://%s - that is where the main box answers now. If your computer is plugged into the service port and that page does not open, use http://%s instead.').format(hosts[0], hosts[hosts.length - 1])
				: _('Still not back. Check that the cable is still in the service port, then reload this page.')));
	}

	function probe() {
		if (Date.now() > deadline || Date.now() > hardStop) {
			giveUp();
			return;
		}
		/* Any answer means the box is serving again - a login redirect or a
		 * refused session are both "it is up", which is all we are asking. */
		(hosts ? probeHosts() : probeOnce()).then(function(up) {
			if (!up) { sawItLeave = true; window.setTimeout(probe, 3000); return; }
			if (!sawItLeave && Date.now() < stopWaitingForIt) {
				window.setTimeout(probe, 3000);
				return;
			}
			askState().then(function(st) {
				if (st === 'failed') {
					dom.content(hint, _('The box came back but did not finish joining. Sign in and open Network - EasyMesh to see what it is stuck on.'));
					return;
				}
				if (st === 'working') {
					if (Date.now() > hardStop) { giveUp(); return; }
					/* Still finishing, and finishing means one more
					 * restart. Watch for it to leave again, and give
					 * that round its own clock - a slow board can
					 * spend longer here than the whole join so far -
					 * but never past hardStop. */
					sawItLeave = false;
					stopWaitingForIt = Date.now() + 180000;
					deadline = Math.min(Date.now() + 300000, hardStop);
					dom.content(hint, _('Almost there - the box is applying what the mesh told it. This can take a few more minutes.'));
					window.setTimeout(probe, 3000);
					return;
				}
				window.location = home;
			});
		});
	}
	window.setTimeout(probe, waitDown ? 3000 : 20000);
}

/* newAddr: the address the box answers at after this reboot, when that is
 * not the one this page is on - only founding moves it. */
function successWithReboot(text, newAddr) {
	var callReboot = rpc.declare({ object: 'system', method: 'reboot' });
	var btn = E('button', { 'class': 'cbi-button cbi-button-apply', 'style': 'margin-top:8px' }, _('Reboot now'));
	var box = E('div', {}, [ note(text, 'good'), btn ]);
	btn.addEventListener('click', function() {
		busy(btn, true);
		callReboot().then(function() {
			dom.content(box, []);
			narrate(box, 'cable');
			if (newAddr && newAddr != window.location.host)
				rebootOverlay(null,
					_('This takes a few minutes. The main box then answers at http://%s, and the login screen opens there on its own.').format(newAddr),
					false, [ newAddr, window.location.host ]);
			else
				rebootOverlay();
		}, function() {
			window.location = L.url('admin/system/reboot');
		});
	});
	return box;
}


/* The join narrator. Polls setup_state through the null rpcd session on
 * purpose: the wizard itself asks for a reboot, the reboot kills the sysauth
 * session, and the story must not stop at a login wall. setup_state is
 * read-only and public by ACL for exactly this. Fetch failures are part of
 * the story too - that is the box restarting itself. */
function narrate(container, air) {
	function line(done, active, text) {
		return E('div', { 'style': 'margin:6px 0;opacity:' + (done || active ? '1' : '.45') },
			(done ? '\u2713 ' : (active ? '\u23f3 ' : '\u25cb ')) + text);
	}
	function renderSteps(st, down) {
		if (st.role == 'controller') {
			var up = st.ap_count > 0;
			dom.content(container, [
				E('h4', {}, _('Founding the mesh\u2026')),
				line(true, false, _('Set up as the mesh controller') + (st.mesh_addr ? (' (' + st.mesh_addr + ')') : '')),
				line(up, !down && !up, _('Starting the mesh network')),
				down
					? note(_('The box is restarting itself - this page will catch it when it comes back.'), 'warn')
					: (up
						? note(_('The mesh is up and this box runs it. Add the other boxes one at a time - the setup screen on each new box will guide you.'), 'good')
						: E('p', { 'style': 'color:#69707a;font-size:12px' }, _('This takes a minute or two.')))
			]);
			return;
		}
		var gotKey = st.bh_key === true;
		var hasIf = !!st.bsta_ifname;
		var connected = st.bsta_links > 0;
		dom.content(container, [
			E('h4', {}, _('Joining the mesh\u2026')),
			line(true, false, _('Set up as an agent') + (st.mesh_addr ? (' (' + st.mesh_addr + ')') : '')),
			line(gotKey, !down && !gotKey, air === true ? _('Keys received over the air') : (air === 'cable' ? _('Receiving settings from the mesh over the cable') : _('Receiving settings from the mesh'))),
			line(hasIf, !down && gotKey && !hasIf, _('Building the wireless link')),
			line(connected, !down && hasIf && !connected, _('Connecting to the mesh')),
			down
				? note(_('The box is restarting itself - this page will catch it when it comes back.'), 'warn')
				: (connected
					? note([
						/* air is true, 'cable' or absent - and 'cable' is a
						 * truthy string, so a plain "air ?" told every wired
						 * join that no cable had ever been involved while the
						 * user was looking at the cable. Test for true. */
						/* No number here, on purpose. Both of these promised
						 * one - "twice" over the air, "once" on the cable -
						 * and both were short: measured 2026-08-15, an air
						 * join takes three restarts and a wired one two, and
						 * the finisher skips its restart when the fronthaul
						 * already matches, so even the true numbers are not
						 * constant. The overlay stopped counting restarts for
						 * the same reason; a sentence that keeps counting
						 * just moves the wrong promise somewhere the user
						 * reads it at the end instead of the beginning.
						 *
						 * Since 2026-09-20 the air join does not reboot at
						 * all unless its one fallback reboot is needed, so it
						 * no longer says it did; the cable join still went
						 * through the Reboot now the user pressed. */
						air === true
							? _('In the mesh - joined over the air, no cable was ever involved. If LuCI asks you to sign in again, do so - then see it in ')
							: _('In the mesh. The cable can stay where it is - the mesh blocks the second path on its own and keeps the wire as a standby - or you can unplug it and the box carries on over the air. The box restarted along the way, so LuCI may ask you to sign in again - then see it in '),
						E('a', { 'href': L.url('admin/network/easymesh/overview') }, _('Overview')),
						'.'
					], 'good')
					: E('p', { 'style': 'color:#69707a;font-size:12px' }, air === 'cable' ? _('This usually takes a few minutes. Leave the cable in.') : _('This usually takes a few minutes. The box restarts once by itself on the way - that is expected.')))
		]);
	}
	var last = {};
	var wasDown = false;
	/* The box reboots itself mid-story, and the reboot kills the LuCI
	 * session and halts the framework that drives this view - so the page
	 * freezes on its last state and the user has to refresh by hand. The
	 * narrator's own /ubus poll (null session) survives and sees the box
	 * come back; on that down->up edge we do once what the user was doing
	 * by hand - reload the page, which re-establishes the session and lets
	 * render() pick the story up fresh. A sessionStorage guard keyed to the
	 * reboot count keeps it a single reload, never a loop. */
	function reloadOnce(tag) {
		try {
			if (sessionStorage.getItem('em-reload') === tag) return false;
			sessionStorage.setItem('em-reload', tag);
		} catch (e) {}
		location.reload();
		return true;
	}
	function tick() {
		fetch('/ubus', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'call',
				params: [ '00000000000000000000000000000000', 'easymesh', 'setup_state', {} ] })
		}).then(function(r) { return r.json(); }).then(function(j) {
			var st = (j.result && j.result[1]) || null;
			if (st && wasDown) { if (reloadOnce(String(st.boot_id || st.uptime || 'up'))) return; }
			if (st) { last = st; wasDown = false; renderSteps(st, false); }
			else { wasDown = true; renderSteps(last, true); }
			var settled = st && (st.role == 'controller' ? st.ap_count > 0 : st.bsta_links > 0);
			if (!settled) setTimeout(tick, 5000);
		}).catch(function() {
			wasDown = true;
			renderSteps(last, true);
			setTimeout(tick, 5000);
		});
	}
	renderSteps(last, false);
	tick();
	return container;
}

function busy(el, on, label) {
	el.disabled = on;
	el.textContent = on ? _('Working…') : label;
}

return view.extend({
	load: function() {
		return callState().catch(function() { return {}; });
	},

	render: function(state) {
		state = state || {};
		var out = E('div', {}, [ E('h2', {}, _('EasyMesh setup')) ]);

		/* On a box that is not in a mesh yet, the other tabs have nothing
		 * to show - so they are visibly parked, not merely empty. Greyed
		 * rather than hidden: the user should see what the product has,
		 * and that setting up is what unlocks it. The per-view guards stay
		 * for anyone arriving by direct URL. */
		if (!state.role || state.role == 'unconfigured') {
			document.querySelectorAll('ul.tabs li a, .cbi-tabmenu li a').forEach(function(a) {
				var href = a.getAttribute('href') || '';
				if (href.indexOf('/easymesh/') >= 0 && href.indexOf('/setup') < 0) {
					a.parentNode.style.opacity = '.35';
					a.parentNode.style.pointerEvents = 'none';
				}
			});
		}


		/* A box mid-join must narrate, not go mute: the user just pressed
		 * reboot on a promise. Checkpoints from setup_state, refreshed
		 * every few seconds, ending with the one instruction that remains. */
		if (state.role == 'agent' && !(state.bsta_links > 0)) {
			var steps = E('div', { 'style': 'max-width:520px' });
			narrate(steps);
			out.appendChild(steps);
			return out;
		}

		/* A configured node keeps its setup reachable - roles do change -
		 * but never one accidental click away from reconfiguring a box
		 * that a running mesh depends on. The form stays hidden until the
		 * user says, in so many words, that reconfiguring is what they
		 * came here to do. */
		if (state.role == 'controller' || state.role == 'agent') {
			var locked = E('div', { 'style': 'max-width:520px' });
			/* The likeliest reason a user opens Setup on a working
			 * controller is to add another box - and the trap is that the
			 * join choice below configures THIS box as an agent, the exact
			 * opposite. So on a controller, lead with where adding a box
			 * actually happens (the Pair button in Overview) and keep the
			 * reconfigure form behind a deliberate second click. */
			if (state.role == 'controller') {
				/* The button, not this page - and in the order that leaves
			 * the most time: this box first, the new one second. wps_open
			 * re-arms the window for about seven minutes, while the new
			 * box waits only about three (easymesh-wps-join), so this is
			 * the same order Overview gives.
			 *
			 * This used to end with "then run setup on the NEW box", which
			 * sent people into the LuCI of a box that is not on the network
			 * yet and has no address to be reached at. It also contradicted
			 * the other two screens, which both lead with the button; a
			 * reader who saw both was told opposite things by the same
			 * interface. */
			locked.appendChild(note([
					_('Adding another box to the mesh? Press "Pair a new box" in '),
					E('a', { 'href': L.url('admin/network/easymesh/overview') }, _('Overview')),
					_(' (or press the WPS button on this box briefly), then hold the WPS button on the new box for 4 to 8 seconds and let go. This box keeps pairing open for about seven minutes. The new box joins on its own in about four to six minutes, with nothing to type in, and restarts once by itself on the way. Nothing on this page needs changing for that.')
				], 'good'));
			}
			locked.appendChild(note(_('This box is already set up as ') + state.role +
				(state.mesh_addr ? (' (' + state.mesh_addr + ')') : '') +
				_('. Reconfiguring a box that is part of a running mesh can take it out of that mesh.'), 'warn'));
			/* Reconfiguring is DISABLED, and the button is gone rather than
			 * greyed out, because two separate things have to be fixed
			 * before it does what its label promises (both measured
			 * 2026-08-22, from the code rather than by pressing it):
			 *
			 * 1. The form it opens comes up EMPTY, and the address field is
			 *    not prefilled - '10.10.10.1' sits in it as a grey hint that
			 *    reads like the current value. Leaving it alone sends
			 *    10.10.10.1, so a mesh running on 172.16.10.1 would silently
			 *    move its controller into a different network than its own
			 *    agents.
			 *
			 * 2. Even a correct change would not reach the agents: the
			 *    fronthaul SSID does not propagate from the controller. The
			 *    mesh would end up advertising two different names and
			 *    clients would drop on the first roam.
			 *
			 * When it comes back it should offer the fronthaul SSID and
			 * password ONLY, both prefilled, only on a controller, and it
			 * must push the change out to the agents. Address, backhaul key
			 * and role are how the nodes talk to each other and are not the
			 * user's to retype.
			 *
			 * Removing the button is deliberate: a disabled one invites
			 * people to hunt for what would enable it. */
			if (state.role != 'controller') {
				/* One box owns the answer. An agent relaying WSC was
				 * measured not to work (2026-08-11), and two boxes writing
				 * credentials is how a mesh gets two answers to one
				 * question. Say where to go rather than offering a field
				 * that would lie. */
				locked.appendChild(note(
					_('The network name and password are changed on the controller, not here. This box takes them from the mesh on its own once they change there.'),
					'warn'));
			} else {
				/* Behind a second click, and the same reasoning as the
				 * founding form above: renaming a running mesh is a
				 * legitimate thing to want and must never be one stray
				 * click away. */
				var reBox = E('div', { 'style': 'display:none;max-width:520px' });
				var reLink = E('a', { 'href': '#', 'style': 'font-size:.85em' },
					_('Change the network name or password ›'));
				reLink.addEventListener('click', function(ev) {
					ev.preventDefault();
					reLink.style.display = 'none';
					reBox.style.display = '';
				});

				var reOut = E('div', {});
				var reBtn = E('button', { 'class': 'cbi-button cbi-button-apply' },
					_('Change it'));
				reBtn.addEventListener('click', function() {
					var ns = val('em-rssid'), nk = val('em-rkey');
					if (!ns)
						return ui.addNotification(null, E('p', _('The network needs a name.')));
					if (new TextEncoder().encode(ns).length > 32)
						return ui.addNotification(null, E('p', _('The network name can be at most 32 bytes.')));
					if (nk.length < 8 || nk.length > 63)
						return ui.addNotification(null, E('p', _('The WiFi password needs 8 to 63 characters.')));
					busy(reBtn, true);
					callSetCreds(ns, nk).then(function(r) {
						busy(reBtn, false, _('Change it'));
						if (!r || r.error)
							return dom.content(reOut, note(_('Could not change it: ') +
								((r && r.error) || _('unknown error')), 'bad'));
						if (r.unchanged)
							return dom.content(reOut, note(_('That is what it is called already - nothing was changed.'), 'good'));
						/* The other boxes need no help and no visit: the
						 * controller sends an AP-Autoconfiguration Renew and
						 * each agent takes the new credentials and restarts
						 * once to put them into service. This box does the
						 * same thing, and it is the one the user is looking
						 * at, so it is the one that has to say so. */
						dom.content(reOut, successWithReboot(
							_('Changed. The other boxes take the new name from the mesh by themselves and restart once - nothing to do on any of them. This box needs the same restart to start using it, and every device will have to be told the new password.')));
					}, function() {
						busy(reBtn, false, _('Change it'));
						dom.content(reOut, note(_('Could not change it - the controller did not answer.'), 'bad'));
					});
				});

				/* Prefilled with what the network is ACTUALLY called, not a
				 * grey hint that reads like it. The founding form's address
				 * field did the latter, and leaving it alone moved a mesh
				 * running on 172.16.10.1 to 10.10.10.1 (measured
				 * 2026-08-22). A field that is empty when it means "keep the
				 * current value" is the same trap wearing a different hat. */
				callCreds().then(function(c) {
					c = c || {};
					dom.content(reBox, [
						note(_('Only the network name and its password. The mesh addresses, the backhaul key and the roles are how the boxes talk to each other - they are not retyped here and are not affected.'), 'warn'),
						row(_('Network name'), _('What you will see on your phone.'),
							input('em-rssid', 'text', '', c.ssid || '')),
						row(_('WiFi password'), _('At least 8 characters.'),
							pwinput('em-rkey', c.wifi_key || '')),
						reBtn,
						reOut
					]);
				}, function() {
					dom.content(reBox, note(_('Could not read what the network is currently called, so nothing is offered here - changing it blind would be worse than not offering it.'), 'bad'));
				});

				locked.appendChild(E('div', { 'style': 'margin-top:1.5em' }, [ reLink, reBox ]));
			}
			out.appendChild(locked);
			return out;
		}

		renderForm();
		return out;

		function renderForm() {

		/* No own no-password warning here: LuCI's banner right above this
		 * view already says it, louder and with a button. Saying it twice
		 * teaches the reader to skip yellow boxes. */

		var result = E('div', {});

		/* ---- founding ---- */
		var foundBtn = E('button', { 'class': 'cbi-button cbi-button-apply' }, _('Create the mesh'));
		foundBtn.addEventListener('click', function() {
			var ssid = val('em-ssid'), key = val('em-key');
			if (!ssid) return ui.addNotification(null, E('p', _('The network needs a name.')));
			if (new TextEncoder().encode(ssid).length > 32) return ui.addNotification(null, E('p', _('The network name can be at most 32 bytes.')));
			if (key.length < 8 || key.length > 63) return ui.addNotification(null, E('p', _('The WiFi password needs 8 to 63 characters.')));

			busy(foundBtn, true);
			var addr = val('em-addr') || '10.10.10.1';
			callFound(ssid, key, val('em-rootpw'), addr, val('em-name') || state.hostname || '', val('em-bhkey')).then(function(r) {
				busy(foundBtn, false, _('Create the mesh'));
				result.innerHTML = '';
				result.appendChild(r && r.ok
					? successWithReboot(_('Mesh created. Press Reboot now to bring it up, then add the other boxes one at a time.'), r.address || addr)
					: note(_('Setup failed: ') + ((r && (r.error || r.log)) || _('unknown error')), 'bad'));
			});
		});

		/* Moving the controller role onto a different box in an existing
		 * mesh: the standing agents hold the old backhaul key and have no
		 * wire to be told a new one over, so the new controller must found
		 * the mesh with the key the old one used. Folded away because the
		 * everyday founding flow must stay a form with nothing cryptic on
		 * it - whoever needs this field knows exactly why. */
		var advanced = E('details', { 'style': 'margin-bottom:14px;max-width:360px' }, [
			E('summary', { 'style': 'cursor:pointer;color:#69707a' }, _('Taking over an existing mesh?')),
			row(_('Backhaul key'), _('The key the previous controller used. Leave empty to generate a fresh one - right for a brand new mesh, wrong for this.'), pwinput('em-bhkey'))
		]);

		var founding = E('div', { 'style': 'max-width:420px' }, [
			E('p', {}, _('A mesh is one main box and any number of others. This box becomes the main one: it keeps the network name and password below and hands them to every box that joins later. You only fill this in once - every box you add afterwards joins by holding its WPS button, with nothing to type in.')),
			row(_('Network name'), _('What you will see on your phone.'), input('em-ssid')),
			row(_('WiFi password'), _('At least 8 characters.'), pwinput('em-key')),
			row(_('This box is called'), _('Shown in the mesh map.'), input('em-name', 'text', '', state.hostname || '')),
			row(_('Mesh addresses'), _('Leave it alone unless it clashes with something.'), input('em-addr', 'text', '10.10.10.1')),
			advanced,
			foundBtn
		]);

		/* ---- joining ---- */
		var joinBtn = E('button', { 'class': 'cbi-button cbi-button-apply' }, _('Join the mesh'));
		joinBtn.addEventListener('click', function() {
			busy(joinBtn, true);
			callJoin(val('em-jname') || state.hostname || '', val('em-gw') || '10.10.10.1').then(function(r) {
				busy(joinBtn, false, _('Join the mesh'));
				result.innerHTML = '';
				result.appendChild(r && r.ok
					? successWithReboot(_('Set up as an agent at ') + (r.address || '?') +
						_('. Leave the cable in and press Reboot now - the box takes its settings from the mesh, and after that it works over the air.'))
					: note(_('Setup failed: ') + ((r && (r.error || r.log)) || _('unknown error')), 'bad'));
			});
		});

		/* ---- joining over the air ----
		 * The wireless twin of the cable join, proven end-to-end 2026-08-11:
		 * this box gets the backhaul key over WPS (Multi-AP M8) from the
		 * controller. Two buttons, one on each box, pressed within the same
		 * two minutes - the pairing model everyone already knows. The
		 * address field is the one honesty of v1: without the cable there
		 * is no wire to probe for a free address, so the user picks it. */
		var wpsBtn = E('button', { 'class': 'cbi-button cbi-button-apply' }, _('Join over the air'));
		var wpsStat = E('div', {});
		function wpsTicker(wgw) {
			/* The air join restarts the box twice on its own, and the ticker
			 * used to poll straight through both: the router stops answering,
			 * the catch below just schedules another try, and the last message
			 * stays on screen unchanged. That is what the user reads as a page
			 * that stopped - "preparing the radio" forever, measured
			 * 2026-08-13. The overlay already knows how to wait for a box, it
			 * was simply never told about the reboots nobody pressed a button
			 * for.
			 *
			 * The two are not the same handover. The first restart is the
			 * middle of the join - the resume init carries on by itself - so
			 * the wait ends back on this page, where the story continues. The
			 * second is the end of it, and there is nothing left here to come
			 * back to: the state file died with the reboot and the pending
			 * note was already removed, so this wizard would greet a box that
			 * is in the mesh with a blank setup form. That one belongs at the
			 * login screen. */
			var handedOver = false;
			function handOver(dest, hintText, waitDown) {
				if (handedOver) return;
				handedOver = true;
				rebootOverlay(dest, hintText, waitDown);
			}
			function tickw() {
				if (handedOver) return;
				callWpsStatus().then(function(s) {
					var st = (s && s.state) || '';
					/* The gateway outlives the reboot in the pending note, so
					 * a resumed page can name the controller it was actually
					 * told to pair with. */
					if (s && s.gateway) wgw = s.gateway;
					if (st.indexOf('preparing the radio') === 0) {
						dom.content(wpsStat, note(st, 'warn'));
						handOver(window.location.href,
							_('Getting the radio ready. The setup screen comes back on its own and the join carries on - leave this window open.'), true);
						return;
					}
					if (st.indexOf('ready') === 0) {
						dom.content(wpsStat, note([
							_('Ready - step 3: press "Pair a new box" on the controller ('),
							E('a', { 'href': 'http://' + wgw + '/cgi-bin/luci/admin/network/easymesh/overview', 'target': '_blank' }, wgw),
							')'
						], 'warn'));
					} else if (st.indexOf('joined') === 0) {
						/* No narrator here: the adopt reboot is seconds away
						 * and the narrator would race the overlay for the
						 * page, one reloading it while the other waits. The
						 * good news moves into the wait itself. */
						busy(wpsBtn, false, _('Join over the air'));
						dom.content(wpsStat, note(_('In the mesh - joined over the air, no cable was ever involved.'), 'good'));
						handOver(window.location.origin + '/cgi-bin/luci/',
							_('In the mesh. The box is finishing its setup, which can take a few minutes, and restarts once by itself at the end - that is expected. Then the login screen comes back, and the new box is in Overview.'), true);
						return;
					} else if (st.indexOf('error') === 0) {
						busy(wpsBtn, false, _('Join over the air'));
						var rb = E('button', { 'class': 'cbi-button', 'style': 'margin-top:8px' }, _('Restart this box and try again'));
						rb.addEventListener('click', function() {
							busy(rb, true);
							rpc.declare({ object: 'system', method: 'reboot' })().then(function() {
								dom.content(wpsStat, note(_('Restarting - when the login screen returns, press "Join over the air" again.'), 'warn'));
								rebootOverlay();
							});
						});
						dom.content(wpsStat, [
							note(_('Join failed: ') + st.replace(/^error: */, ''), 'bad'),
							E('p', { 'style': 'font-size:12px;color:#69707a' }, _('A retry works best from a clean start - the radio remembers failed attempts.')),
							rb
						]);
						return;
					} else {
						dom.content(wpsStat, note(st || _('Working…'), 'warn'));
					}
					setTimeout(tickw, 3000);
				}).catch(function() { setTimeout(tickw, 3000); });
			}
			tickw();
		}

		wpsBtn.addEventListener('click', function() {
			/* The address carries the network with it: the controller of a
			 * mesh always sits at .1 of its own subnet (that is what the
			 * founding form's address means), so the gateway is derived,
			 * not asked for - and a number from some other network is
			 * refused here, not discovered as a mystery later. */
			var waddr = val('em-waddr');
			if (!/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(waddr))
				return ui.addNotification(null, E('p', _('Put in the address the controller shows next to "Pair a new box" - four numbers with dots, e.g. 10.10.10.4.')));
			var wgw = waddr.replace(/\.\d+$/, '.1');
			busy(wpsBtn, true);
			callWpsJoin(val('em-jname') || state.hostname || '',
					wgw, waddr).then(function(r) {
				if (!(r && r.ok)) {
					busy(wpsBtn, false, _('Join over the air'));
					dom.content(wpsStat, note(_('Could not start the join: ') + ((r && r.error) || _('unknown error')), 'bad'));
					return;
				}
				wpsTicker(wgw);
			});
		});

		/* The join screen leads with the choice, and the air comes first:
		 * that is the product's order (button pairing is the primary way in,
		 * the cable is the fallback), and the cable instructions only appear
		 * once the cable is what the user picked - a screen that opens with
		 * "connect a cable" sends people hunting for one they do not need. */
		var airPane = E('div', {}, [
			note(E('div', {}, [
				E('div', { 'style': 'margin-bottom:6px' }, _('This takes one button here and one on the controller - have both screens open:')),
				E('div', {}, _('1. Open the controller’s LuCI in another tab. Next to its "Pair a new box" button it shows the address to copy below.')),
				E('div', {}, _('2. Press "Join over the air" here and wait for Ready.')),
				E('div', {}, _('3. Then press "Pair a new box" over there. The mesh hands the keys over by itself.')),
				/* This listed three restarts (clean radio, join, network
				 * name), measured 2026-08-15. Since 2026-09-20 each of
				 * those is a restart of the services, not of the box
				 * (easymesh-soft-restart). Since 2026-09-30 (5588bef) the
				 * box reboots once more after the join has settled - the
				 * one step known to leave the driver clean - so every join
				 * ends with exactly one restart. */
				E('div', { 'style': 'margin-top:6px;color:#8a6d0b' }, _('The box then sets itself up on its own and restarts once by itself on the way - that is expected. Just wait until this page says it is in the mesh.'))
			]), 'warn'),
			row(_('Mesh address for this box'), _('Copy it exactly from the controller - it shows the number next to its "Pair a new box" button (e.g. 10.10.10.4). The network part must match the mesh.'), input('em-waddr', 'text', '')),
			wpsBtn,
			wpsStat
		]);
		var cablePane = E('div', {}, [
			note(_('Connect a cable from this box to one that is already in the mesh, and leave it in until this finishes. That cable is how it is told the network password - nothing to type, and nothing to get wrong.'), 'warn'),
			row(_('Address of the first box'), _('Leave it alone unless you changed it when you created the mesh.'), input('em-gw', 'text', '10.10.10.1')),
			joinBtn
		]);

		/* No second fork. The recommended way IS the screen: name, address,
		 * one button. The cable is a quiet link for whoever really wants
		 * it - a fallback offered as an equal choice stops being a
		 * fallback and starts being homework. */
		var subPane = E('div', {});
		var toCable = E('a', { 'href': '#', 'style': 'font-size:12px' }, _('Joining with a cable instead ›'));
		var toAir = E('a', { 'href': '#', 'style': 'font-size:12px' }, _('‹ back to joining over the air'));
		function showAir() {
			subPane.innerHTML = '';
			subPane.appendChild(airPane);
			subPane.appendChild(E('div', { 'style': 'margin-top:14px' }, [ toCable ]));
		}
		function showCable() {
			subPane.innerHTML = '';
			subPane.appendChild(cablePane);
			subPane.appendChild(E('div', { 'style': 'margin-top:14px' }, [ toAir ]));
		}
		toCable.addEventListener('click', function(ev) { ev.preventDefault(); showCable(); });
		toAir.addEventListener('click', function(ev) { ev.preventDefault(); showAir(); });
		showAir();

		var joining = E('div', { 'style': 'max-width:420px' }, [
			row(_('This box is called'), _('Shown in the mesh map.'), input('em-jname', 'text', '', state.hostname || '')),
			subPane
		]);

		/* ---- the fork ----
		 * A wizard walks forward: once the user has answered the opening
		 * question, the question leaves the screen. What stays is a one-line
		 * breadcrumb saying which path this is, with the only way back
		 * spelled out - two dead buttons above a form would just invite a
		 * mid-flow click that throws the form away. */
		var pane = E('div', {});
		/* Founding is the only thing this screen still offers as a choice.
		 *
		 * Adding a box is not configuration any more - it is two button
		 * presses and no typing - so putting it here as a co-equal option
		 * would send the reader back into the journey the button was built
		 * to delete: a second web interface, on a box not yet on the network,
		 * reached over a cable nobody should need. It is written out as an
		 * instruction instead, which is what it now is.
		 *
		 * The old path is kept, one click down, and honestly labelled. It is
		 * the way in when a radio will not come up, which has happened here
		 * more than once this year - deleting it would leave a box with a
		 * dead radio with no way in at all. Demoted, not removed. */
		var bFound = E('button', { 'class': 'cbi-button cbi-button-apply' }, _('This is my first box'));
		var bJoin = E('button', { 'class': 'cbi-button', 'style': 'margin-top:8px' }, _('Set it up over a cable'));
		var fallback = E('div', { 'style': 'display:none;margin-top:8px' }, [
			E('p', { 'style': 'color:#888;font-size:.85em;max-width:520px' },
				_('Needs a cable into this box and an address you choose yourself. Worth reaching for when a radio has not come up and the box cannot be invited over the air - otherwise the button does the same thing without asking anything.')),
			bJoin
		]);
		var fallbackLink = E('a', { 'href': '#', 'style': 'font-size:.8em;color:#888' }, _('Advanced: set this box up over a cable'));
		fallbackLink.addEventListener('click', function(ev) {
			ev.preventDefault();
			fallback.style.display = '';
			fallbackLink.style.display = 'none';
		});
		var forkIntro = E('div', { 'style': 'max-width:560px' }, [
			E('p', {}, _('Is this the first box of a new mesh?')),
			E('p', { 'style': 'color:#69707a' },
				_('The first box keeps the network name and password and hands them to every box added later.'))
		]);
		var forkBtns = E('div', { 'style': 'margin-bottom:18px' }, [
			bFound,
			E('h3', { 'style': 'margin-top:1.6em' }, _('Adding it to a mesh you already have?')),
			E('p', { 'style': 'max-width:560px' },
				/* The main box and no other. An agent refuses the press
				 * (30-easymesh), and on a BPI-R4 a refused short press
				 * falls through to the stock reset handler, which restarts
				 * that box - "a box that is already in the mesh" sent
				 * people to exactly that. */
				_('Then this screen is not needed. Leave the box plugged in. First, on the main box (the first one you set up), press "Pair a new box" in its Overview or hold its WPS button for 4 to 8 seconds. Then hold the WPS button on this box for 4 to 8 seconds and let go. The main box keeps pairing open for about seven minutes, so there is time to walk over; the other order works too, but leaves only about three. This box joins on its own in about four to six minutes, with nothing to type in, and restarts once by itself on the way. Do not keep holding: ten seconds or more erases the box instead.')),
			E('div', { 'style': 'margin-top:2.5em;text-align:right;max-width:560px' }, [ fallbackLink, fallback ])
		]);

		function choose(which) {
			forkIntro.style.display = 'none';
			forkBtns.style.display = 'none';
			pane.innerHTML = '';
			result.innerHTML = '';
			var back = E('a', { 'href': '#' }, _('‹ start over'));
			back.addEventListener('click', function(ev) {
				ev.preventDefault();
				forkIntro.style.display = '';
				forkBtns.style.display = '';
				pane.innerHTML = '';
				result.innerHTML = '';
			});
			pane.appendChild(E('div', { 'style': 'margin-bottom:12px;color:#69707a;font-size:12px' }, [
				(which == 'found' ? _('Founding a new mesh') : _('Adding this box to a mesh you already have')),
				' — ', back
			]));
			pane.appendChild(which == 'found' ? founding : joining);
		}

		bFound.addEventListener('click', function() { choose('found'); });
		bJoin.addEventListener('click', function() { choose('join'); });

		out.appendChild(forkIntro);
		out.appendChild(forkBtns);
		out.appendChild(pane);
		out.appendChild(result);

		/* A refresh in the middle of a join must pick the story back up,
		 * not hand the user a blank form while the worker labours on. */
		callWpsStatus().then(function(s0) {
			var st0 = (s0 && s0.state) || '';
			if (!st0) return;
			if (st0.indexOf('joined') === 0) {
				choose('join');
				dom.content(wpsStat, []);
				narrate(wpsStat, true);
			} else if (st0.indexOf('error') !== 0) {
				/* The gateway comes from the pending note, which outlived the
				 * reboot that brought us here. Guessing the default subnet
				 * sent everyone on another one to a controller that is not
				 * theirs, and the reboot handover above makes this the normal
				 * path rather than the rare hand-refresh it used to be. */
				choose('join');
				busy(wpsBtn, true);
				wpsTicker((s0 && s0.gateway) || '10.10.10.1');
			}
		}).catch(function() {});
		}
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
