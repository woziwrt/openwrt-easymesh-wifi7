# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# Where a mesh node's address comes from.
#
# Sourced, not executed. Defines mesh_addrs_in_use(), pick_mesh_addr() and
# ask_controller_addr(), and nothing else.
#
# ⚠️ The originals of these functions live inline in the rpcd handler
# (easymesh-api, /usr/libexec/rpcd/easymesh) and still run from there: that
# package does not depend on easymesh-wifi, so it cannot source this file yet.
# Two copies is one copy too many - when easymesh-api gains the dependency,
# delete the inline ones and source this instead. Until then, a change here
# must be made there too.
#
# The two are kept byte-identical from the first comment below to the end of
# the file, on purpose, so that a plain diff of the two files says whether they
# have drifted. On 2026-09-04 they had not - and it still cost a round of the
# same bug being fixed in one copy first.
#
# The reservation ledger that decides the answers is NOT here: it belongs to
# the controller alone and lives in the rpcd handler. This file only knows how
# to ask it, and how to guess badly if it cannot be reached.

# The low end of the mesh network, .2 upwards, is where nodes live. It is
# deliberately below the DHCP pool: the controller hands clients .100-.249,
# and a node that settles inside that range holds an address dnsmasq will
# give away again the moment its lease lapses. Measured 2026-08-23: an agent
# took the offered .170 statically, and the lease behind it had 12 hours to
# live. It is also the number the controller prints next to "Pair a new box",
# so a node that picks it here matches what the screen promised.
#
# arping -D asks with no source address at all, which is why this works on a
# box that has not got one yet - the whole reason a joining node can run it.

# Every address in the mesh subnet this box KNOWS is spoken for.
#
# Silence on the wire is not evidence of an address being free, and no number
# of repeats makes it into evidence. The ARP probe below already learned that
# once (2026-08-10, a node three rooms out) and answered it by asking twice.
# On 2026-09-04 the same fault came back on a five-node mesh of depth 3: the
# node holding .2 sat three wireless hops away, all six probes were lost, and
# .2 was handed to a second box. The node that had it first went off the map
# entirely - it kept an address that now answers somewhere else.
#
# Two rounds were not enough because more rounds are the wrong instrument. A
# broadcast that has to survive three wireless hops fails for reasons that do
# not average out, and the one box that never has to guess is the controller:
# ieee1905d reports an ipv4_address for every device in the topology, at any
# depth, over 1905 rather than over broadcast ARP. That is the same source the
# Nodes tab already draws the address column from, so nothing new is collected
# here - it is only asked before an address is given away instead of after.
#
# ALL of a device's ipv4 entries are taken, not the first: a node may hold two
# (the controller holds .1, .253 and .254), and reading only the first would
# report the others as free. Over-reporting is the safe direction - the worst
# it costs is a node numbered .5 instead of .3.
#
# The neighbour table and the DHCP leases are added because they cost nothing
# and cover what 1905 cannot see: a box that is on the wire without being in
# the mesh. Entries with no lladdr, or in FAILED/INCOMPLETE, are the leftovers
# of our own earlier probes and mean the opposite of occupied.
mesh_addrs_in_use() {
	local prefix="$1" mb="$2"
	{
		ubus -t 5 call ieee1905.topology dump 2>/dev/null |
			sed -n 's/^[[:space:]]*"ip":[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p'
		ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1
		if [ -n "$mb" ]; then
			ip -4 neigh show dev "$mb" 2>/dev/null
		else
			ip -4 neigh show 2>/dev/null
		fi | awk '/lladdr/ && !/FAILED|INCOMPLETE/ {print $1}'
		awk '{print $3}' /tmp/dhcp.leases 2>/dev/null
	} | awk -F. -v p="$prefix" 'NF==4 && $1"."$2"."$3==p {print}' | sort -u
}

pick_mesh_addr() {
	local base="${1%.*}" iface n=2 used
	# Second argument overrides the probe interface: the wired join asks on
	# the lan bridge it shares with the mesh, the controller (suggesting an
	# address for an over-the-air join) asks on the mesh bridge itself.
	iface="${2:-$(uci -q get network.lan.device)}"
	iface="${iface:-br-lan}"
	command -v arping >/dev/null 2>&1 || return 1
	# Asked once, before the walk: the answer cannot change under it, and the
	# walk skips whole ranges without paying six seconds of ARP for each.
	#
	# Third argument is a newline-separated list of addresses to treat as
	# taken although nothing on the wire says so yet. That is what the
	# controller's reservation ledger passes in, and it is the only thing
	# here that can rule out an address BEFORE its box starts using it.
	used=$(printf '%s\n%s\n' "$(mesh_addrs_in_use "$base" "$iface")" "$3" |
		grep -v '^$' | sort -u)
	while [ $n -le 99 ]; do
		# Knowledge vetoes, silence only confirms. An address somebody is
		# known to hold is never probed - that is the case ARP gets wrong -
		# and an address nobody is known to hold still has to be silent
		# twice before it is handed out, which is what catches a box that
		# is on the wire without being in the mesh.
		if echo "$used" | grep -Fxq "$base.$n"; then
			n=$((n + 1))
			continue
		fi
		if arping -D -q -c 3 -w 3 -I "$iface" "$base.$n" >/dev/null 2>&1; then
			sleep 1
			if arping -D -q -c 3 -w 3 -I "$iface" "$base.$n" >/dev/null 2>&1; then
				echo "$base.$n"
				return 0
			fi
		fi
		n=$((n + 1))
	done
	return 1
}

# Ask the controller to hand out an address AND write it down in one step.
#
# Every local probe - ARP, 1905, the neighbour table - can only report a state
# that has already happened. Between "the controller worked out that .2 is
# free" and "the box that was given .2 starts answering on it" there is a
# window in which every one of them still says free, and on 2026-09-04 two
# boxes were configured minutes apart and both landed on .2 through exactly
# that window. Measuring harder does not close it; only writing the answer
# down before it is used does, and only one box can keep that ledger.
#
# So the box that needs an address stops working it out and asks. It sends
# the name it will be known by, so a box that comes back gets its own number
# back rather than the next free one.
#
# Deliberately not jsonfilter: this runs from easymesh-wifi too, which does
# not depend on it, and the answer is one flat object.
ask_controller_addr() {
	local ctrl="$1" almac="$2" sess out
	[ -n "$ctrl" ] || return 1
	command -v curl >/dev/null 2>&1 || return 1
	sess=$(curl -s --max-time 5 -X POST -H 'Content-Type: application/json' \
		-d '{"jsonrpc":"2.0","id":1,"method":"call","params":["00000000000000000000000000000000","session","login",{"username":"root","password":""}]}' \
		"http://$ctrl/ubus" 2>/dev/null |
		sed -n 's/.*"ubus_rpc_session":"\([a-f0-9]*\)".*/\1/p')
	[ -n "$sess" ] || return 1
	out=$(curl -s --max-time 12 -X POST -H 'Content-Type: application/json' \
		-d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"call\",\"params\":[\"$sess\",\"easymesh\",\"claim_address\",{\"almac\":\"$almac\"}]}" \
		"http://$ctrl/ubus" 2>/dev/null)
	out=$(echo "$out" | sed -n 's/.*"address":"\([0-9][0-9.]*\)".*/\1/p' | head -1)
	[ -n "$out" ] || return 1
	echo "$out"
}
