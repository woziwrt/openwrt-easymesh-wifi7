# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# easymesh core - node identity and names.
#
# A box has no stable hardware MAC on these boards, so it is remembered by an
# AL-MAC that is drawn fresh on every boot. Everything about telling one box
# from another lives here.
#
# Requires db.sh (sq1). Source db.sh first.
#
# ---------------------------------------------------------------------------
# WHERE A NAME LIVES  (decided 2026-09-06, measured the same day)
#
# In the box, as its system hostname. Nowhere else. The controller keeps a
# ledger ABOUT names but is never the authority on one.
#
# There are three doors into that hostname and they all lead to the same field:
#
#   LuCI on the box      user types it standing next to the box
#   the pencil in the    the controller writes it over the mesh
#     mesh table
#   name restore         the controller puts a name back on a box that came
#                        home carrying a factory name (reflash, factory reset)
#
# The old design had the pencil write a private override file here and treat
# that file as the strongest source. Measured 2026-09-06 on node .3: after one
# use of the pencil the box was renamed at the box to CELLAR, ieee1905 carried
# CELLAR to the controller - and the picture kept drawing BEDROOM, forever. A
# stored copy that outranks the thing it is a copy of is not a cache, it is a
# second truth, and the two had already disagreed.
#
# So the file below stopped being an override and became a LEDGER with a state
# per line:
#
#   <al-mac> <name> heard     the last real name this box reported. Memory:
#                             it names a box that is switched off, and it is
#                             what a reflashed box gets back.
#   <al-mac> <name> pending   typed by a user, not yet confirmed BY THE BOX.
#                             Cleared when the box reports it - never when the
#                             write was merely sent (2026-09-04: a fuse written
#                             before the work turns the step off forever).
#
# A two-column line is a ledger from before this change. It is read as pending,
# which is the safe reading: it gets pushed to the box and becomes heard once
# the box confirms, so an old override converges to the truth instead of
# outranking it.
#
# Neither state ever outranks a real name coming off the wire.
# ---------------------------------------------------------------------------

NAMES=/etc/mesh-node-names

# What the factory calls a box, i.e. "this box has no name yet".
#
# The list is 99-set-hostname's, deliberately: that script asks the same
# question ("is this still a default name?") to decide whether it may
# overwrite the hostname, and two lists would drift. The generated form
# BPI-R4-89e7c5 is a factory name too - it identifies the box but nobody chose
# it - and the pattern is tight (exactly six hex) so a hand-typed
# BPI-R4-kitchen is a real name.
#
# Why it matters that this is not just cosmetic: a box that comes back from a
# factory reset reports a factory name, and following it blindly would erase
# "Bedroom" from the picture because somebody reflashed a box. A factory name
# is not a name, it is the absence of one.
is_factory_name() {
	case "$1" in
	""|OpenWrt|openwrt|BPI-R4|BPI-R4-SD|BPI-R4-NAND|BPI-R4-eMMC|BPI-R4-NVMe)
		return 0 ;;
	BPI-R4-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
		return 0 ;;
	esac
	return 1
}

# Two boxes with the same label read as one box, which is the exact confusion
# the naming was meant to end. And identical labels are the NORMAL starting
# state, not an edge case: 99-set-hostname names a box after the medium it
# booted from, so every node ships answering the same thing - measured
# 2026-08-25, three lab agents all called themselves 'BPI-R4-SD', and again
# 2026-09-06, four of five nodes.
#
# So the label is left exactly as the box reports it while it is unique, and
# only a name that collides picks up the tail of its AL-MAC. Nothing is written
# anywhere - this is how the name is DRAWN, not what the name IS.
dedupe_names() {
	sed 's/^{//; s/}$//' | tr ',' '\n' | sed 's/^"//; s/"$//; s/":"/\t/' | awk -F'\t' '
		NF == 2 {
			if (!($1 in seen)) { order[++n] = $1; seen[$1] = 1 }
			name[$1] = $2
		}
		END {
			for (i = 1; i <= n; i++) cnt[name[order[i]]]++
			printf "{"
			for (i = 1; i <= n; i++) {
				k = order[i]; v = name[k]
				if (cnt[v] > 1) {
					t = k; gsub(/:/, "", t)
					v = v " (" substr(t, length(t) - 5) ")"
				}
				printf "%s\"%s\":\"%s\"", sep, k, v; sep = ","
			}
			print "}"
		}'
}

# Every name currently on the wire, factory names included.
#
# The factory ones are kept here and filtered by the caller rather than
# dropped: a node whose only name is BPI-R4-89e7c5 must still draw as
# BPI-R4-89e7c5 and not as a bare MAC address, which is what dropping it used
# to produce.
live_names_json() {
	ubus -t 5 call ieee1905.topology dump 2>/dev/null | awk '
		BEGIN { sep = ""; printf "{" }
		/"ieee1905id"/ { id = $2; gsub(/[",]/, "", id); next }
		/"name"/ {
			n = $2; gsub(/[",]/, "", n)
			# A name arrives over the wire from any box in the mesh and ends
			# up in LuCI pages and in commands run on other boxes: only a
			# hostname-shaped one is taken, anything else is not a name.
			if (n !~ /^[A-Za-z0-9._-]+$/ || length(n) > 63) n = ""
			if (id != "" && n != "") {
				printf "%s\"%s\":\"%s\"", sep, id, n
				sep = ","
			}
			id = ""
		}
		END { print "}" }'
}

# Split a flat {"mac":"name",...} map by whether the name is a real one.
# WANT is "real" or "factory". Small maps (one line per node), so a shell loop
# is cheaper than starting another interpreter.
filter_names_json() {
	local want="$1" body pair k v out=""
	body=$(sed 's/^{//; s/}$//')
	IFS=','
	for pair in $body; do
		k=$(echo "$pair" | sed 's/^[[:space:]]*"//; s/":".*//')
		v=$(echo "$pair" | sed 's/.*":"//; s/"[[:space:]]*$//')
		[ -n "$k" ] || continue
		if is_factory_name "$v"; then
			[ "$want" = factory ] || continue
		else
			[ "$want" = real ] || continue
		fi
		out="$out${out:+,}\"$k\":\"$v\""
	done
	unset IFS
	echo "{$out}"
}

# The ledger, as a flat map, for one state.
ledger_json() {
	local want="$1"
	[ -f "$NAMES" ] || { echo '{}'; return; }
	awk -v want="$want" 'BEGIN{s=""}
		/^[0-9a-fA-F:]+[ \t]/ {
			st = (NF >= 3 ? $3 : "pending")
			if (st != want) next
			printf "%s\"%s\":\"%s\"", s, tolower($1), $2; s=","
		}
		END{ print "" }' "$NAMES" | sed 's/^/{/; s/$/}/'
}

ledger_get() {           # ledger_get <almac> -> "name state", empty if absent
	[ -f "$NAMES" ] || return 1
	awk -v m="$(echo "$1" | tr 'A-Z' 'a-z')" '
		tolower($1) == m { print $2, (NF >= 3 ? $3 : "pending"); exit }' "$NAMES"
}

# Rewrite the line for one node. Atomic by tmp+mv - NOT by flock: busybox
# flock has no -w and fails on the switch itself, silently (measured
# 2026-09-04, the address ledger never wrote a single line because of it).
ledger_set() {           # ledger_set <almac> <name> <state>
	local mac name state tmp
	mac=$(echo "$1" | tr 'A-Z' 'a-z'); name="$2"; state="$3"
	[ -n "$mac" ] && [ -n "$name" ] || return 1
	touch "$NAMES" 2>/dev/null || return 1
	tmp="$NAMES.tmp.$$"
	grep -v -i "^$mac[[:space:]]" "$NAMES" 2>/dev/null > "$tmp"
	printf '%s %s %s\n' "$mac" "$name" "$state" >> "$tmp"
	mv "$tmp" "$NAMES"
}

ledger_del() {           # ledger_del <almac>
	local mac tmp
	mac=$(echo "$1" | tr 'A-Z' 'a-z')
	[ -f "$NAMES" ] || return 0
	tmp="$NAMES.tmp.$$"
	grep -v -i "^$mac[[:space:]]" "$NAMES" 2>/dev/null > "$tmp"
	mv "$tmp" "$NAMES"
}

# The name every consumer draws.
#
# Weakest first, because every consumer parses last-key-wins, so the order
# below IS the priority:
#
#   live factory   better than a MAC address, worse than anything chosen
#   heard          memory; names a box that is switched off
#   pending        the user's latest instruction, not yet confirmed
#   live real      what the box says about itself right now - always wins
#
# The top of that list is the whole point. A user standing at a box and
# renaming it must see the picture follow, even if somebody once used the
# pencil on that same box. Measured 2026-09-06: with the old order it never
# did.
names_json() {
	local live live_real live_fact heard pend merged=""
	live=$(live_names_json)
	case "$live" in "{"*"}") ;; *) live="{}";; esac
	live_fact=$(echo "$live" | filter_names_json factory)
	live_real=$(echo "$live" | filter_names_json real)
	heard=$(ledger_json heard)
	pend=$(ledger_json pending)

	for part in "$live_fact" "$heard" "$pend" "$live_real"; do
		case "$part" in ""|"{}") continue ;; esac
		[ -n "$merged" ] && merged="$merged,"
		merged="$merged$(x=${part#\{}; echo "${x%\}}")"
	done
	echo "{$merged}" | dedupe_names
}

# Which of the drawn names is not confirmed by its box yet.
#
# The picture must not present an instruction as a fact: a name typed for a
# box that was switched off is a promise, and saying so is the difference
# between a user who waits and a user who types it again.
pending_json() {
	local pend live_real out="" body pair k v
	pend=$(ledger_json pending)
	case "$pend" in ""|"{}") echo '{}'; return ;; esac
	live_real=$(live_names_json | filter_names_json real)
	body=$(echo "$pend" | sed 's/^{//; s/}$//')
	IFS=','
	for pair in $body; do
		k=$(echo "$pair" | sed 's/^[[:space:]]*"//; s/":".*//')
		v=$(echo "$pair" | sed 's/.*":"//; s/"[[:space:]]*$//')
		[ -n "$k" ] || continue
		# A box that is on the air with a real name is not waiting for
		# anything - the reconciler is about to drop this line.
		case "$live_real" in *"\"$k\":"*) continue ;; esac
		out="$out${out:+,}\"$k\":\"$v\""
	done
	unset IFS
	echo "{$out}"
}

# A warning names the node it is about. "1 node(s) not heard" tells the reader
# that something is wrong and nothing about where to look, and looking is the
# entire point of raising it.
#
# Same priority as names_json, for the same reason. The database is not asked:
# map-controller never learns a node's friendly name (it is carried in the
# 1905 Device Identification TLV, which ieee1905d parses and map-controller
# does not), so the agent table has no device_name column and the query that
# used to be here failed on every single call - silently, because sq1 returns
# empty on error and empty reads as "nothing stored". Checked 2026-09-06:
# "no such column: device_name".
nameof() {
	local mac n st
	mac=$(echo "$1" | tr 'A-Z' 'a-z')
	n=$(live_names_json | filter_names_json real |
		sed -n "s/.*\"$mac\":\"\([^\"]*\)\".*/\1/p")
	[ -n "$n" ] || n=$(ledger_get "$mac" | awk '{print $1}')
	[ -n "$n" ] || n=$(live_names_json | sed -n "s/.*\"$mac\":\"\([^\"]*\)\".*/\1/p")
	echo "${n:-$1}"
}

# The address of every node, straight out of 1905 - no ARP matching, no table
# of our own. ieee1905d already collects an ipv4_address for each device it
# reaches and hands it over on ubus, so a two-hop node the controller has never
# had a session with reports its address like everyone else.
#
# Why it is worth drawing: the picture names the boxes but the user has to
# reach them, and the addresses are handed out by the mesh rather than typed
# (lowest free in .2-.99, in join order). Without this the only way to learn
# which box sits on which address is to go and ask each one.
#
# The ipv6 block carries an "ip" key too and comes after the ipv4 one, so only
# the first per device is taken, and only if it looks like IPv4 - a node with
# num_ipv4 = 0 must contribute nothing rather than an address of the wrong kind.
#
# A device that reports no address - a foreign agent answers no Higher Layer
# Query, so ieee1905d never learns one (MediaTek R3, 2026-09-18) - is looked
# up by its own interface addresses in the neighbour table of the mesh bridge
# and in the DHCP leases, by the MACs of its own interfaces, exactly or with
# only the 4th octet different (see below). Only its interfaces count: the dump also
# lists the MACs of its neighbours, and one of those is the Mac on its Wi-Fi,
# whose address this would otherwise hand to the box.
#
# And it remembers. ieee1905d drops a foreign agent from its topology for a
# few seconds at a time (MediaTek R3 on the BPI-R4 Pro 8X, 2026-09-18: present, absent for
# ~10 s, present again), and while it is absent none of its interfaces can be
# matched - the picture lost the address and pairing refused to suggest one.
# The last address seen for each node is kept for ADDR_CACHE_S; an address
# that may still be in use is reported as in use, which is the safe side.
ADDR_CACHE=/tmp/easymesh-addr-cache
ADDR_CACHE_S=${ADDR_CACHE_S:-600}

live_addrs_json() {
	local now
	now=$(date +%s)
	# fresh answers first, then what is remembered; the first line per
	# node wins, and a remembered one only while it is younger than the limit
	{
		live_addrs_now | tr -d '{}"' | tr ',' '\n' |
			sed -n "s/^\([0-9a-f:]\{17\}\):\([0-9.]*\)$/\1 \2 $now/p"
		cat "$ADDR_CACHE" 2>/dev/null
	} | awk -v t="$now" -v max="$ADDR_CACHE_S" '
		NF == 3 && !($1 in ip) && t - $3 < max { ip[$1] = $2; ts[$1] = $3 }
		END { for (k in ip) print k, ip[k], ts[k] }' > "$ADDR_CACHE.$$" &&
		mv "$ADDR_CACHE.$$" "$ADDR_CACHE"
	awk 'BEGIN { sep = ""; printf "{" }
		NF == 3 { printf "%s\"%s\":\"%s\"", sep, $1, $2; sep = "," }
		END { print "}" }' "$ADDR_CACHE" 2>/dev/null
}

live_addrs_now() {
	{
		ip -4 neigh show dev br-lan 2>/dev/null |
			awk '/lladdr/ && !/FAILED|INCOMPLETE/ { print "N", tolower($5), $1 }'
		awk '{ print "N", tolower($2), $3 }' /tmp/dhcp.leases 2>/dev/null
		echo "DUMP"
		ubus -t 5 call ieee1905.topology dump 2>/dev/null
	} | awk '
		function flush() {
			if (id != "" && ip == "") {
				n = split(macs, m, " ")
				for (i = 1; i <= n; i++)
					if (m[i] in addr) { ip = addr[m[i]]; break }
				# MediaTek gives each LAN port the bridge address with
				# the 4th octet raised by 16 per port and reports only
				# the ports, while the lease is taken on the bridge
				# (EasyMesh_openwrt.sh, 2026-09-18: ports ..:d6/e6/f6..,
				# lease on ..:c6..). Five octets out of six, and only
				# when no other owner shares them.
				for (i = 1; ip == "" && i <= n; i++) {
					k = substr(m[i], 1, 9) substr(m[i], 12)
					if ((k in addr5) && addr5[k] != "") ip = addr5[k]
				}
			}
			if (id != "" && ip != "") {
				printf "%s\"%s\":\"%s\"", sep, id, ip
				sep = ","
			}
			id = ""; ip = ""; macs = ""; inif = 0
		}
		BEGIN { sep = ""; printf "{" }
		!dump && $1 == "N" {
			if (!($2 in addr)) addr[$2] = $3
			# the same address with the 4th octet left out; two different
			# owners of one key make it useless, so it is dropped
			k = substr($2, 1, 9) substr($2, 12)
			if (!(k in addr5)) addr5[k] = $3
			else if (addr5[k] != $3) addr5[k] = ""
			next
		}
		!dump && $0 == "DUMP" { dump = 1; next }
		/"ieee1905id"/ { flush(); id = $2; gsub(/[",]/, "", id); next }
		/"interface": \[/ { inif = 1; depth = 0 }
		inif {
			depth += gsub(/\[/, "[") - gsub(/\]/, "]")
			if ($1 == "\"macaddress\":") {
				v = $2; gsub(/[",]/, "", v); macs = macs " " tolower(v)
			}
			if (depth <= 0) inif = 0
			next
		}
		/"ip"/ {
			if (id == "" || ip != "") next
			v = $2; gsub(/[",]/, "", v)
			if (v ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) ip = v
		}
		END { flush(); print "}" }'
}
