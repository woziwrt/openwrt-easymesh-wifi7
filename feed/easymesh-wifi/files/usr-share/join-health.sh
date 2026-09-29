# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# /usr/share/easymesh/join-health.sh - is this node finished joining?
#
# Sourced, not run. Two callers ask the same question at different moments:
# easymesh-soft-restart after it has rebuilt the radios, and bh-key-adopt when
# the join reaches its end. They have to agree, because one of them decides
# whether the box spends its fallback reboot on what the other just did. Two
# private copies of these rules would drift within a week, and the day they
# disagreed we would be debugging the difference instead of the node.
#
# What it does NOT do is decide. It reports what is wrong, as words; the
# caller says what that is worth where it stands in the join.

# One look. Prints what is wrong, empty when nothing is.
#
# Everything here is conditional on what the box is configured to be. A node
# in phase one has no role, no mesh daemons and no MLDs, and it is not broken
# for lacking them - it simply has not got there yet.
join_health_links() { iw dev "$1" info 2>/dev/null | grep -c "channel "; }

# How many links an MLD should carry: the radios its wifi-iface lists that
# are not switched off. Until 2026-09-29 this was 3 and 2 written in, so a box
# with one radio held down failed every look and spent its fallback reboot on
# a configuration somebody chose (review C9, 2026-09-27). Empty when the
# config does not say.
join_health_want() {
	local s r n=0
	for s in $(uci show wireless 2>/dev/null | sed -n "s/^wireless\.\([^.=]*\)\.ifname='$1'$/\1/p"); do
		[ "$(uci -q get wireless.$s)" = wifi-iface ] || continue
		for r in $(uci -q get wireless.$s.device); do
			[ "$(uci -q get wireless.$r.disabled)" = 1 ] || n=$((n + 1))
		done
		echo "$n"
		return 0
	done
}

# join_health_once [phase1|mid|final]
#
#   phase1 - the box is only preparing its radios; it has no credentials yet,
#            so the MLDs legitimately carry fewer links than they will.
#   mid    - the default, during a join
#   final  - the join is over, everything is expected to stand
#
# See the notes at each criterion for which level it belongs to.
join_health_once() {
	local bad="" r s sp _chk want_ip _on _self _nb _p _age _when="${1:-mid}"

	# How many links an MLD carries is only a fair question once the box has
	# the credentials to build them with. In phase one it has not: the radios
	# are being prepared and the MLDs come up short by design. Measured
	# 2026-09-20 on kitchen and hall, both of which joined perfectly while
	# phase one reported "FAIL: ap-mld-1=2/3 ap-mld-2=0/2". Harmless while it
	# only went to the log - but from today a verdict like that is what the
	# fallback reboot decides on, so it has to stop lying.
	if [ "$_when" != phase1 ]; then
		_p=$(join_health_want ap-mld-1)
		[ -d /sys/class/net/ap-mld-1 ] && [ "$(join_health_links ap-mld-1)" != "${_p:-3}" ] &&
			bad="$bad ap-mld-1=$(join_health_links ap-mld-1)/${_p:-3}"
		_p=$(join_health_want ap-mld-2)
		[ -d /sys/class/net/ap-mld-2 ] && [ "$(join_health_links ap-mld-2)" != "${_p:-2}" ] &&
			bad="$bad ap-mld-2=$(join_health_links ap-mld-2)/${_p:-2}"
		[ -d /sys/class/net/bsta-mld-3 ] &&
			! iw dev bsta-mld-3 link 2>/dev/null | grep -q 'Connected to' &&
			bad="$bad bsta-not-associated"
	fi

	# EVERY radio switched off, not any of them. The case this was written for
	# (2026-09-19 r3) is a node that reported itself healthy with all three
	# radios down and therefore no interfaces to check. One radio held down is
	# a configuration somebody chose - and since this verdict now costs a
	# reboot, punishing that choice would spend one on every join, for ever.
	_on=0
	for r in radio0 radio1 radio2; do
		uci -q get wireless.$r >/dev/null 2>&1 || continue
		[ "$(uci -q get wireless.$r.disabled)" = 1 ] || _on=$((_on + 1))
	done
	[ "$_on" = 0 ] && bad="$bad all-radios-disabled"

	# Phase one is allowed to be half-built, but not empty: if the radios are
	# enabled in config and `iw dev` shows nothing at all, the wireless stack
	# did not come back and no amount of waiting will fix it (2026-08-19).
	[ "$_on" -gt 0 ] && ! iw dev 2>/dev/null | grep -q Interface &&
		bad="$bad no-wireless-interfaces"
	for s in $(uci show wireless 2>/dev/null |
		sed -n "s/^wireless\.\([^.=]*\)\.ifname='\(ap-mld-[0-9]*\|bsta-mld-[0-9]*\)'$/\2/p" |
		sort -u); do
		[ -d /sys/class/net/$s ] || bad="$bad $s-missing"
	done

	# Only what this box is configured to run: before the role is set (phase 1)
	# the mesh daemons are legitimately off.
	_chk="ieee1905:ieee1905d wifimngr:wifimngr"
	[ -f /etc/mapc/role ] && _chk="$_chk mapagent:mapagent"
	for sp in $_chk; do
		/etc/init.d/${sp%%:*} enabled 2>/dev/null && ! pidof ${sp#*:} >/dev/null &&
			bad="$bad ${sp#*:}-not-running"
	done

	# The two below are asked ONLY at the end of a join ("final"), never in the
	# middle of one ("mid", the default, which is what easymesh-soft-restart
	# uses). Both are legitimately untrue while a join is still running:
	#
	#   the address - the join writes the mesh address into uci and netifd
	#   raises it a moment later; soft-restart runs up to four times inside
	#   that window,
	#
	#   the neighbour - 1905 Topology Discovery is on a 60 s period and this
	#   verdict only watches for 20 s, so a freshly started ieee1905d has
	#   legitimately seen nobody yet.
	#
	# Asking them mid-join would fail a healthy node, and now that a failure
	# costs a reboot, it would spend one on a join that was going fine.
	[ "$_when" = final ] || { echo "$bad"; return 0; }

	# The address the config asks for, actually on the bridge. A join that
	# took a mesh address and then failed to raise it leaves a node that
	# carries client traffic perfectly and is invisible from the mesh - the
	# 2026-08-22 finding, in the form a check can see. -F: an address is not
	# a regular expression.
	want_ip=$(uci -q get network.lan.ipaddr)
	[ -n "$want_ip" ] && ! ip -4 -o addr show br-lan 2>/dev/null |
		grep -qF " ${want_ip%/*}/" && bad="$bad br-lan-not-$want_ip"

	# And somebody out there, which for a joined agent means its parent.
	#
	# Counted as DISTINCT AL addresses that are not this box. Measured
	# 2026-09-20 on the corridor agent with exactly one neighbour: `ieee1905
	# info | grep -c ieee1905id` says 3 - itself once, the neighbour twice,
	# because the structure nests. Any threshold on that number is a guess
	# about the shape of the output; this counts the thing we mean.
	#
	# But it must not be asked faster than 1905 can answer. Topology Discovery
	# goes out every 60 s, and the verdict only watches for 20 s, so a node
	# that has just finished its join can be perfectly fine and still have
	# heard nobody yet. That is not theory: on 2026-09-20 corridor spent its
	# one fallback reboot on exactly this, and came back "healthy" - not
	# because the reboot repaired anything, but because by then a discovery
	# had been due. The other three nodes of the same evening passed only
	# because their neighbour happened to arrive inside the window.
	#
	# So the question is only asked once ieee1905d has been running longer
	# than one discovery period. Before that, silence means "too early", and
	# too early must never read as broken.
	if [ -f /etc/mapc/role ]; then
		_p=$(pidof ieee1905d 2>/dev/null | cut -d' ' -f1)
		_age=0
		[ -n "$_p" ] && [ -r "/proc/$_p" ] &&
			_age=$(awk -v t="$(cut -d' ' -f1 /proc/uptime)" \
				'{ print int(t - $22 / 100) }' "/proc/$_p/stat" 2>/dev/null)
		case "$_age" in ''|*[!0-9]*) _age=0 ;; esac
		if [ "$_age" -ge 75 ]; then
			_self=$(uci -q get ieee1905.ieee1905.macaddress | tr 'A-Z' 'a-z')
			_nb=$(ubus -t 5 call ieee1905 info 2>/dev/null |
				sed -n 's/.*"ieee1905id": *"\([^"]*\)".*/\1/p' |
				tr 'A-Z' 'a-z' | grep -v "^${_self:-no-self-address}$" |
				sort -u | grep -c .)
			[ "${_nb:-0}" = 0 ] && bad="$bad no-1905-neighbours"
		fi
	fi

	echo "$bad"
}

# Three looks, 10 s apart, and a verdict only on what all three agree about.
#
# One look is not a measurement: on 2026-09-19 round b3-4 a check reported
# ap-mld-2=2/2 while the message a moment later showed one link. The links of
# an MLD arrive over seconds, daemons are restarted by their own init scripts,
# and a single unlucky sample would spend a reboot on a node that was fine.
#
# Matching is on WHAT is wrong (ap-mld-1), not on the exact count (1/3 vs 2/3):
# a link count that is wrong in three different ways is still wrong.
# Sets JOIN_HEALTH_BAD (the verdict) and JOIN_HEALTH_LOOKS (what the three
# looks saw). It returns them in variables rather than on stdout on purpose:
# `bad=$(join_health_verdict)` would run the whole thing in a SUBSHELL, and
# the second answer - the three looks, which is the part worth keeping in the
# fuse - would die with it. Callers read the variables, and the return code
# says whether anything is wrong, so `if join_health_verdict; then` reads well.
join_health_verdict() {
	local b1 b2 b3 k1 k2 x bad="" when="${1:-mid}"

	b1=$(join_health_once "$when"); sleep 10
	b2=$(join_health_once "$when"); sleep 10
	b3=$(join_health_once "$when")

	k1=" $(for x in $b1; do printf '%s ' "${x%%=*}"; done)"
	k2=" $(for x in $b2; do printf '%s ' "${x%%=*}"; done)"
	for x in $b3; do
		case "$k2" in *" ${x%%=*} "*)
			case "$k1" in *" ${x%%=*} "*) bad="$bad $x" ;; esac ;;
		esac
	done

	JOIN_HEALTH_LOOKS="$b1 |$b2 |$b3"
	JOIN_HEALTH_BAD="$bad"
	[ -z "$bad" ]
}
