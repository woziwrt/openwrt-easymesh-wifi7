# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# easymesh trace - the boot chain writes down what it did.
#
# Sourced as the first line of every shell script between power-on and a
# formed mesh. It answers, without anyone having to guess afterwards:
#
#     who ran this          full parent chain, pid, argv, environment
#     when                  wall clock and monotonic uptime, to the millisecond
#     what it found         a full state snapshot before the script body runs
#     what it left behind   the same snapshot after, plus the diff between them
#     what it did           a line-by-line xtrace of the body in between
#
# Everything lands in ONE file, /root/easymesh-trace/trace.log, in the order
# it happened, so the boot reads top to bottom. /root and not /tmp on purpose:
# the interesting failures are the ones you only understand after the reboot.
#
# This file is measurement scaffolding, not product. It is installed by
# easymesh-trace-install and removed by the same tool. Nothing in the feed
# depends on it and nothing in it changes behaviour - it only reads.

ET_DIR=${ET_DIR:-/root/easymesh-trace}
ET_LOG=$ET_DIR/trace.log
ET_SNAPDIR=$ET_DIR/.snap
ET_LOCK=$ET_DIR/.lock
ET_TICKFILE=$ET_DIR/.seq

# Knobs live in a file so they can be changed on a running box without
# touching the scripts again.
#
#   ET_ENABLE=0        trace nothing (the off switch that needs no uninstall)
#   ET_XTRACE=0        keep the records and snapshots, drop the line-by-line
#   ET_PS4_TIME=1      timestamp EVERY traced line - one fork per line, which
#                      costs tens of seconds across a boot and can move the
#                      boot races we are hunting. Microscope mode: turn it on
#                      for one script, never for a whole boot.
#   ET_SNAP_DEPTH      full = every probe, fast = skip the slow ones
#   ET_MINFREE_MB      stop writing rather than fill the rootfs
[ -f /etc/easymesh-trace.conf ] && . /etc/easymesh-trace.conf
ET_ENABLE=${ET_ENABLE:-1}
# Whitelist that overrides ET_ENABLE=0, as space-separated globs matched
# against the script name. This is the answer to the objection that an
# instrument changes what it measures: with ET_ENABLE=0 the hook costs a few
# milliseconds and the boot runs at its normal speed, while the two or three
# scripts named here still get the full record. A race that only appears at
# full speed stays visible, and we still see inside the scripts that matter.
#
#   ET_ENABLE=0
#   ET_ONLY_TAGS="easymesh-role bh-key-adopt easymesh-genconfig map_genconfig"
ET_ONLY_TAGS=${ET_ONLY_TAGS:-}
# Order-only mode: one line when a script starts, one when it ends, and
# nothing else. No snapshots, no xtrace, no re-exec - a few milliseconds.
#
# Full tracing does not slow the boot evenly: a script with full snapshots
# pays about 0.6 s and one in ET_FAST_TAGS about 0.25 s. An even slowdown
# would preserve order; an uneven one REORDERS, so a hotplug handler can
# overtake an init script that would otherwise have gone first. That makes
# full tracing the wrong instrument for hunting a race - it can hide one as
# easily as expose one.
#
# This mode answers "who ran, when, in what order, and how long" and changes
# almost nothing while doing it. Use it first; turn on snapshots for the two
# or three scripts that the ordering points at.
ET_EVENTS_ONLY=${ET_EVENTS_ONLY:-0}
ET_XTRACE=${ET_XTRACE:-1}
ET_PS4_TIME=${ET_PS4_TIME:-0}
ET_SNAP_DEPTH=${ET_SNAP_DEPTH:-full}
ET_MINFREE_MB=${ET_MINFREE_MB:-48}
# Shell glob, matched against the script name. These run on every wifi event,
# several at a time, and a full snapshot each would be more load than the mesh.
ET_FAST_TAGS=${ET_FAST_TAGS:-"multiap dpp traffic_separation 00-sysctl 10-mt7996-txpower-fix hotplug-call 20-mld-bsta-bridge node-heartbeat hostapd-watch mld-bsta-relink mld-bsta-bridge"}

# ---------------------------------------------------------------- primitives

# Monotonic, in milliseconds. /proc/uptime is centiseconds; a boot trace needs
# an ordering key that a wrong RTC cannot scramble, and every board here comes
# up years in the past until something sets the clock.
_et_up() {
	local a b
	read -r a b < /proc/uptime 2>/dev/null || { echo 0; return; }
	echo "${a}"
}

_et_wall() { date '+%Y-%m-%d %H:%M:%S' 2>/dev/null; }

# Blocks are written under a lock so two scripts starting in the same second
# do not interleave their snapshots. Single lines are appended without it:
# an O_APPEND write below the pipe buffer does not tear.
# Blocks are written under a lock so two scripts starting in the same second
# do not interleave their snapshots - but never for longer than five seconds.
# A trace that can block is a trace that changes what it measures: three
# concurrent /lib/wifi/multiap runs waiting on this lock is exactly how the
# first version of this file wedged the box it was watching. Late and slightly
# interleaved beats on time and wrong.
_et_emit_block() {
	[ "$ET_ENABLE" = "1" ] || { cat >/dev/null; return 0; }
	# busybox flock has no -w, only -n, so the wait is ours: a few short tries
	# and then an unlocked append. A failed -n does not consume stdin, which
	# is what makes the retry safe.
	local _i=0
	if command -v flock >/dev/null 2>&1; then
		while [ "$_i" -lt 20 ]; do
			flock -n -x "$ET_LOCK" -c "cat >> '$ET_LOG'" 2>/dev/null && return 0
			_i=$((_i + 1))
			sleep 0.2 2>/dev/null || sleep 1
		done
		echo "### lock busy for 4 s, appending unlocked" >> "$ET_LOG"
	fi
	cat >> "$ET_LOG"
}

_et_line() {
	[ "$ET_ENABLE" = "1" ] || return 0
	printf '%s\n' "$*" >> "$ET_LOG"
}

# Free space guard. A trace that fills the rootfs turns a measurement into an
# outage, and this box is reachable over one cable.
_et_space_ok() {
	local free
	free=$(df -m "$ET_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
	[ -z "$free" ] && return 0
	[ "$free" -gt "$ET_MINFREE_MB" ] 2>/dev/null
}

# Who am I. Scripts with the rc.common shebang are executed as
# `/bin/sh /etc/rc.common /etc/init.d/foo start`, so $0 is the wrapper and the
# name worth logging is in $1.
_et_tag() {
	local self="$1"; shift
	case "$self" in
		*/rc.common) echo "$(basename "${1:-rc.common}")" ;;
		*) echo "$(basename "$self")" ;;
	esac
}

# The parent chain, all the way to init. This is the answer to "who started
# this" - procd, a hotplug event, another one of our scripts, or a human.
_et_ancestry() {
	local pid=$1 depth=0 comm ppid line
	while [ "$pid" -gt 0 ] && [ "$depth" -lt 12 ]; do
		[ -r "/proc/$pid/stat" ] || break
		comm=$(sed -n 's/^[0-9]* (\(.*\)) .*/\1/p' "/proc/$pid/stat" 2>/dev/null)
		ppid=$(sed -n 's/^[0-9]* (.*) . \([0-9]*\) .*/\1/p' "/proc/$pid/stat" 2>/dev/null)
		line=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
		printf '    %-6s %-16s %s\n' "$pid" "$comm" "${line:-[kernel]}"
		[ -z "$ppid" ] && break
		pid=$ppid
		depth=$((depth + 1))
	done
}

# Centiseconds since boot, as an integer, for durations. /proc/uptime is the
# only clock on this box that is monotonic and correct before NTP.
_et_cs() {
	local a b i f
	read -r a b < /proc/uptime 2>/dev/null || { echo 0; return; }
	i=${a%%.*}
	f=${a#*.}
	[ "$f" = "$a" ] && f=0
	# A leading zero makes ash read the number as octal, and "08" is then a
	# syntax error - the trace has to survive the first nine centiseconds of
	# every second.
	f=${f#0}
	[ -n "$f" ] || f=0
	echo $(( i * 100 + f ))
}

_et_ms_str() { # centiseconds -> "12.34 s"
	local cs=$1
	printf '%d.%02d s' "$((cs / 100))" "$((cs % 100))"
}

# ------------------------------------------------------------------- probes
#
# One line per measured parameter. This is the list to extend when a question
# comes up that the trace could not answer - a probe costs one line here and
# is then taken at the start and the end of every script in the chain.
#
#     name  timeout(s)  shell command
#
# "slow" probes are skipped when ET_SNAP_DEPTH=fast.

# Early in a boot ubus is not answering yet. Without this gate every ubus
# probe waits out its timeout, which cost eleven seconds per script on the
# first instrumented boot and stretched the boot chain past six minutes - the
# trace was changing the thing it was measuring.
_et_have_ubus() { timeout 1 ubus -t 1 list >/dev/null 2>&1; }

_et_wlan_ifaces() { iw dev 2>/dev/null | awk '/Interface/ {print $2}'; }

_et_probe_iw_per_iface() {
	local i
	for i in $(_et_wlan_ifaces); do
		echo "--- iw dev $i info"
		iw dev "$i" info 2>&1
		echo "--- iw dev $i link"
		iw dev "$i" link 2>&1
		echo "--- iw dev $i station dump (count)"
		iw dev "$i" station dump 2>/dev/null | grep -c '^Station'
	done
}

_et_probe_hostapd_cli() {
	local s
	for s in /var/run/hostapd/* ; do
		[ -e "$s" ] || continue
		echo "--- hostapd_cli -i $(basename "$s") status"
		timeout 2 hostapd_cli -i "$(basename "$s")" status 2>&1
	done
}

_et_probe_wpa_cli() {
	local s
	for s in /var/run/wpa_supplicant/* ; do
		[ -e "$s" ] || continue
		echo "--- wpa_cli -i $(basename "$s") status"
		timeout 2 wpa_cli -i "$(basename "$s")" status 2>&1
	done
}

_et_probe_runconf() {
	local f
	for f in /var/run/hostapd-*.conf /var/run/hostapd/*.conf /var/run/wpa_supplicant-*.conf; do
		[ -f "$f" ] || continue
		echo "--- $f  (md5 $(md5sum "$f" 2>/dev/null | cut -d' ' -f1))"
		cat "$f" 2>/dev/null
	done
}

_et_probe_ubus_easymesh() {
	local o
	_et_have_ubus || { echo "(ubus not answering)"; return 0; }
	for o in map.agent map.controller ieee1905 wifix wifi; do
		timeout 1 ubus list "$o" >/dev/null 2>&1 || continue
		echo "--- ubus call $o status"
		timeout 2 ubus call "$o" status 2>&1
	done
}

_et_probe_mapc_db() {
	[ -f /etc/mapc/mapc.db ] || { echo "no /etc/mapc/mapc.db"; return; }
	ls -la /etc/mapc/ 2>&1
	command -v sqlite3 >/dev/null 2>&1 || return 0
	local t
	for t in agent radio bss sta topology_link apmld affiliated_ap ttlm; do
		printf '%-16s %s\n' "$t" "$(timeout 2 sqlite3 /etc/mapc/mapc.db "select count(*) from $t;" 2>&1)"
	done
}

# The probe table.  name|command
#
# Commands are eval'd in a subshell of the traced script, so the helpers above
# are available to them. Anything that can block on a wedged daemon carries
# its own `timeout` here - there is no outer one, because an outer timeout
# would need a second shell and would lose the helpers.
_et_probes() {
	cat <<'PROBES'
uptime|cat /proc/uptime; cat /proc/loadavg; free
date|date; echo "role=$(cat /etc/mapc/role 2>/dev/null || echo '<none>')"
markers|ls -la /etc/mapc/ /etc/multiap/ 2>&1; ls -la /etc/easymesh-wps-pending 2>&1
wsc_m2|cat /etc/multiap/wsc_m2.json 2>&1
cfg_md5|md5sum /etc/config/* 2>&1
uci_wireless|uci -q show wireless 2>&1
uci_network|uci -q show network 2>&1
uci_dhcp|uci -q show dhcp 2>&1
uci_mapagent|uci -q show mapagent 2>&1
uci_mapcontroller|uci -q show mapcontroller 2>&1
uci_ieee1905|uci -q show ieee1905 2>&1
uci_other|uci -q show easymesh 2>&1; uci -q show wifimgr 2>&1; uci -q show system 2>&1
ip|ip -br addr 2>&1; echo; ip -br link 2>&1; echo; ip route 2>&1
!bridge|bridge link show 2>&1; echo; bridge fdb show 2>&1 | head -60
iw_dev|iw dev 2>&1; echo; iw reg get 2>&1
!iw_iface|_et_probe_iw_per_iface
wireless_status|_et_have_ubus && timeout 2 ubus call network.wireless status 2>&1 || echo "(ubus not answering)"
!service_list|_et_have_ubus && timeout 3 ubus call service list 2>&1 | head -200 || echo "(ubus not answering)"
!ubus_objects|_et_have_ubus && timeout 2 ubus list 2>&1 || echo "(ubus not answering)"
!ubus_easymesh|_et_probe_ubus_easymesh
!hostapd_cli|_et_probe_hostapd_cli
!wpa_cli|_et_probe_wpa_cli
!runconf|_et_probe_runconf
!mapc_db|_et_probe_mapc_db
procs|ps w 2>&1
rcd|ls /etc/rc.d/ 2>&1
!logtail|timeout 2 logread 2>/dev/null | tail -n 40
!dmesg|timeout 2 dmesg 2>/dev/null | tail -n 40
PROBES
}

# A full state snapshot, every probe timed so a slow probe shows up as a slow
# probe rather than as a slow script.
_et_snapshot() { # $1 = output file, $2 = label
	local out="$1" label="$2"
	{
		echo "######## SNAPSHOT $label  up=$(_et_up)  $(_et_wall)"
		_et_probes | while IFS='|' read -r _n _c; do
			[ -n "$_n" ] || continue
			# A leading ! marks a probe that costs real time. Scripts that
			# run a few times per boot get them; scripts that run on every
			# wifi event do not, or the trace becomes the load.
			case "$_n" in
				!*) [ "$ET_DEPTH" = "full" ] || continue
				    _n=${_n#!} ;;
			esac
			_t0=$(_et_cs)
			echo "#### [$_n]"
			( eval "$_c" ) 2>&1
			echo
			_t1=$(_et_cs)
			echo "#### [$_n] took $(_et_ms_str $((_t1 - _t0)))"
		done
		echo "######## END SNAPSHOT $label"
	} > "$out" 2>&1
}

# One file per boot, and a header that says what this boot is made of - done
# by whichever hooked script runs first, so there is no daemon to keep alive.
# The test is honest: a trace file older than this boot belongs to the last
# one. Clocks on these boards are wrong until something syncs them, but wrong
# consistently, so the comparison holds.
_et_new_boot() {
	local id prev stamp
	mkdir -p "$ET_DIR/boots" 2>/dev/null
	# The kernel hands out a fresh boot_id every boot. The wall clock does
	# not: S00sysfixtime sets the date from a stamp file, so early in a boot
	# "now" is EARLIER than the last line of the previous boot's trace, and a
	# rotation keyed on timestamps never fires. Measured 2026-08-19, which is
	# why the first instrumented boot landed on top of the old one.
	id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
	[ -n "$id" ] || return 0
	prev=$(cat "$ET_DIR/.bootid" 2>/dev/null)
	[ "$id" = "$prev" ] && return 0
	# mkdir is the atomic one. Whoever creates it rotates, everybody else
	# carries on writing - the loser's records land in the fresh file.
	mkdir "$ET_DIR/.rotating" 2>/dev/null || return 0
	echo "$id" > "$ET_DIR/.bootid"
	if [ -s "$ET_LOG" ]; then
		stamp=$(date -r "$ET_LOG" +%Y%m%d-%H%M%S 2>/dev/null || echo old)
		mv "$ET_LOG" "$ET_DIR/boots/boot-$stamp.log" 2>/dev/null
	fi
	rm -rf "$ET_SNAPDIR" 2>/dev/null
	mkdir -p "$ET_SNAPDIR" 2>/dev/null
	ls -1t "$ET_DIR/boots/" 2>/dev/null | tail -n +11 | while read -r f; do
		rm -f "$ET_DIR/boots/$f"
	done
	_et_boot_header
	rmdir "$ET_DIR/.rotating" 2>/dev/null
}

_et_boot_header() {
	{
		echo "################################################################"
		echo "### BOOT  $(_et_wall)  up=$(_et_up)  $(cat /proc/sys/kernel/hostname 2>/dev/null)"
		echo "### $(uname -a)"
		echo "### $(. /etc/openwrt_release 2>/dev/null; echo "$DISTRIB_ID $DISTRIB_RELEASE $DISTRIB_REVISION")"
		echo "### packages:"
		apk list -I 2>/dev/null | grep -E 'easymesh|map-agent|map-controller|ieee1905|libwifi|libeasy|hostapd|wpad|wifimngr' | sed 's/^/###   /'
		echo "### cmdline: $(cat /proc/cmdline 2>/dev/null)"
		echo "### rc.d start order:"
		ls -1 /etc/rc.d/S* 2>/dev/null | sed 's/^/###   /'
		echo "### traced scripts: $(grep -c . "$MANIFEST_FILE" 2>/dev/null) hooked"
		echo "################################################################"
	} | _et_emit_block
}
MANIFEST_FILE=$ET_DIR/.hooked

# What this run changed. There is no diff(1) on these boxes - busybox says
# "applet not found" - and for a fortnight every DIFF block in the trace was
# empty because of it, which is a fine example of an instrument that reports
# nothing and looks like a clean result. This does the comparison with awk,
# which is always there: it is set difference rather than a real diff, so the
# order of lines is lost, but for uci dumps and command output that is exactly
# what we want to read anyway.
_et_diff() {
	awk 'NR==FNR { a[$0]=1; next }
	     /^#### \[.*\] took/ { next }
	     !($0 in a) { print "+ " $0 }' "$1" "$2" 2>/dev/null
	awk 'NR==FNR { b[$0]=1; next }
	     /^#### \[.*\] took/ { next }
	     !($0 in b) { print "- " $0 }' "$2" "$1" 2>/dev/null
}

# ----------------------------------------------------------- arm and disarm

# The END record for a run. Set as an EXIT trap, and on the signals procd uses
# to stop a service, so a stopped daemon still writes down what it left behind.
_et_end() {
	local rc=$1
	[ -n "$ET_ARMED" ] || return 0
	ET_ARMED=
	# Only undo what we turned on: a script someone is debugging with `sh -x`
	# keeps its own trace.
	[ "$ET_XTRACE" = "1" ] && set +x 2>/dev/null
	local dur=$(( $(_et_cs) - ET_T0 ))
	if [ "$ET_ENABLE" = "1" ] && _et_space_ok; then
		_et_snapshot "$ET_SNAPDIR/$ET_ID.end" "END $ET_ID"
		{
			echo
			echo "=== END   $ET_ID  rc=$rc  duration=$(_et_ms_str $dur)  up=$(_et_up)  $(_et_wall)"
			cat "$ET_SNAPDIR/$ET_ID.end"
			echo "=== DIFF  $ET_ID  (what this run changed)"
			if [ -f "$ET_SNAPDIR/$ET_ID.begin" ]; then
				_et_diff "$ET_SNAPDIR/$ET_ID.begin" "$ET_SNAPDIR/$ET_ID.end" | head -400
				echo "=== DIFF END $ET_ID"
			else
				echo "(no BEGIN snapshot - nothing to compare)"
			fi
			echo "=== CLOSED $ET_ID"
			echo
		} | _et_emit_block
	fi
	rm -f "$ET_SNAPDIR/$ET_ID.begin" "$ET_SNAPDIR/$ET_ID.end" 2>/dev/null
}

_et_end_sig() { _et_end "signal-$1"; exit $((128 + $2)); }

# Already armed in this shell means we are a sourced fragment - a hotplug
# handler, or an init script under rc.common. Those get their own record so
# the ordering stays exact, but they must not re-arm: the EXIT trap and the
# stderr redirection belong to the process, not to the fragment.
if [ -n "$ET_ARMED" ]; then
	_et_line "--- SOURCED $(_et_tag "$0" "$@") by $ET_ID  up=$(_et_up)  argv: $*"
	return 0 2>/dev/null || true
fi

# The tag decides whether this run is traced at all, so it is worked out
# before anything else happens.
ET_TAG=$(_et_tag "$0" "$@")
for _p in $ET_ONLY_TAGS; do
	case "$ET_TAG" in $_p) ET_ENABLE=1; break ;; esac
done

if [ "$ET_ENABLE" = "1" ]; then
	mkdir -p "$ET_DIR" "$ET_SNAPDIR" 2>/dev/null
	_et_new_boot
	if _et_space_ok; then
		# busybox ash keeps a private copy of the stderr it was started with
		# and writes the line-by-line trace there, so `exec 2>>log` moves the
		# script's own messages into the trace and leaves the xtrace shouting
		# at the console. The only way to move it is to already have been
		# started with stderr pointing at the log - so hand ourselves to a new
		# shell that is. Same pid, same argv, and every child inherits the fd,
		# which is why one re-exec at the top of a chain is enough.
		#
		# The guard is exported: a script started by procd gets a fresh
		# environment and re-execs itself, a script we called inherits an fd 2
		# that is already the log and must not.
		if [ "$ET_XTRACE" = "1" ] && [ -z "$ET_REEXEC" ] && [ -f "$0" ] && [ -w "$ET_DIR" ]; then
			export ET_REEXEC=1
			exec /bin/sh "$0" "$@" 2>> "$ET_LOG"
		fi

		ET_ARMED=1
		ET_T0=$(_et_cs)
		ET_ID="$ET_TAG.$$"

		# Full detail for the scripts that decide something, cheap records for
		# the ones netifd and hostapd call on every event.
		ET_DEPTH=full
		for _p in $ET_FAST_TAGS; do
			case "$ET_TAG" in $_p) ET_DEPTH=fast; break ;; esac
		done

		if [ "$ET_EVENTS_ONLY" = "1" ]; then
			_et_line "EVENT begin $ET_ID up=$(_et_up) ppid=$PPID argv: $*"
			trap '_et_line "EVENT end   '"$ET_ID"' up=$(_et_up) rc=$?"' EXIT
			return 0 2>/dev/null || exit 0
		fi

		_et_snapshot "$ET_SNAPDIR/$ET_ID.begin" "BEGIN $ET_ID"
		{
			echo
			echo "================================================================"
			echo "=== BEGIN $ET_ID  up=$(_et_up)  $(_et_wall)"
			echo "    script    : $0"
			echo "    argv      : $*"
			echo "    pid/ppid  : $$ / $PPID"
			echo "    cwd       : $(pwd 2>/dev/null)"
			echo "    started by:"
			_et_ancestry "$PPID"
			echo "    environment:"
			env 2>/dev/null | sort | sed 's/^/      /'
			cat "$ET_SNAPDIR/$ET_ID.begin"
			echo "=== BODY  $ET_ID"
		} | _et_emit_block

		trap '_et_end $?' EXIT
		trap '_et_end_sig TERM 15' TERM
		trap '_et_end_sig INT 2' INT
		trap '_et_end_sig HUP 1' HUP

		# From here the script's own stderr and its xtrace share the trace
		# file, in order. Their stderr no longer reaches syslog; logger calls
		# are untouched and still do.
		exec 2>> "$ET_LOG"
		if [ "$ET_XTRACE" = "1" ]; then
			if [ "$ET_PS4_TIME" = "1" ]; then
				PS4='+ $(cut -d" " -f1 /proc/uptime) '"$ET_ID"':$LINENO> '
			else
				PS4='+ '"$ET_ID"':$LINENO> '
			fi
			set -x
		fi
	fi
fi
