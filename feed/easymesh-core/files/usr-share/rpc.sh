# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# How one box of the mesh calls the easymesh API of another (rpcd over HTTP).
#
# The boxes log in to each other as the rpcd user "easymesh", not as root. Its
# password is derived from the backhaul key, which every box of the mesh holds
# (the controller hands it out; an agent cannot join without it), so nobody
# ever types it, and the root password is the owner's business: set, changed
# or empty, the mesh keeps talking. Until 2026-09-27 every call logged in as
# root with an empty password - a box whose owner set a root password went
# deaf to the rest of the mesh (no address for a joining box, empty LuCI pages
# on the agents, no link rates, a blind parent planner).
#
# The "easymesh" user reaches only the easymesh methods the boxes call on each
# other (acl.d/easymesh-mesh.json): the controller's read-only views for the
# agents' LuCI, address claims, link state and scans for the planner, bridge
# flushes, and the moves and renames an agent's LuCI hands to the controller.
# Not setup, credentials, WPS or forget_node: those need a login on the box.
#
# Sourced; needs uci, sha256sum, uhttpd (for the password hash) and curl.

MESH_RPC_USER=easymesh

# The backhaul key of this box: the controller's own, or the one an agent was
# given. Printed, never logged.
mesh_rpc_key() {
	local k="" s i=0
	if [ "$(cat /etc/mapc/role 2>/dev/null)" = controller ]; then
		for s in $(uci show mapcontroller 2>/dev/null |
				sed -n 's/^mapcontroller\.\([^.][^.]*\)=ap$/\1/p'); do
			[ "$(uci -q get mapcontroller.$s.type)" = backhaul ] || continue
			k=$(uci -q get mapcontroller.$s.key) && [ -n "$k" ] && break
		done
	else
		while [ $i -lt 12 ]; do
			if [ "$(uci -q get mapagent.@ap[$i].type)" = backhaul ]; then
				k=$(uci -q get mapagent.@ap[$i].key) && [ -n "$k" ] && break
			fi
			i=$((i + 1))
		done
	fi
	[ -n "$k" ] || return 1
	echo "$k"
}

mesh_rpc_secret() {
	local k
	k=$(mesh_rpc_key) || return 1
	printf 'easymesh-rpc:%s' "$k" | sha256sum | cut -c1-32
}

# Make sure this box accepts the "easymesh" user with the current secret.
# Cheap when nothing changed; called at boot and after a new backhaul key.
mesh_rpc_user() {
	local sec hash
	sec=$(mesh_rpc_secret) || return 0
	hash=$(uhttpd -m "$sec" 2>/dev/null)
	[ -n "$hash" ] || return 1
	[ "$(uci -q get rpcd.$MESH_RPC_USER.password)" = "$hash" ] && return 0
	uci -q batch <<-EOF
		set rpcd.$MESH_RPC_USER=login
		set rpcd.$MESH_RPC_USER.username='$MESH_RPC_USER'
		set rpcd.$MESH_RPC_USER.password='$hash'
		delete rpcd.$MESH_RPC_USER.read
		delete rpcd.$MESH_RPC_USER.write
		add_list rpcd.$MESH_RPC_USER.read='easymesh-mesh'
		add_list rpcd.$MESH_RPC_USER.write='easymesh-mesh'
		commit rpcd
	EOF
	logger -t easymesh-rpc "rpcd user $MESH_RPC_USER set up for the current backhaul key"
}

# mesh_rpc_session <host> - a session token on that box, or nothing.
#
# Only as the "easymesh" user. Until 2026-09-30 a failed login was retried as
# root with an empty password, for boxes on images older than 2026-09-27 that
# know no "easymesh" user. That second try handed any box whose owner had not
# set a root password full access to every ubus object of every other box, to
# anyone holding the backhaul key - and no image that old was ever released.
mesh_rpc_session() {
	local host="$1" sec s
	sec=$(mesh_rpc_secret) || return 1
	s=$(_mesh_rpc_login "$host" "$MESH_RPC_USER" "$sec")
	[ -n "$s" ] || return 1
	echo "$s"
}

_mesh_rpc_login() {
	curl -s --max-time 5 -X POST -H 'Content-Type: application/json' \
		-d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"call\",\"params\":[\"00000000000000000000000000000000\",\"session\",\"login\",{\"username\":\"$2\",\"password\":\"$3\"}]}" \
		"http://$1/ubus" 2>/dev/null |
		sed -n 's/.*"ubus_rpc_session":"\([a-f0-9]*\)".*/\1/p'
}

# mesh_rpc_call <host> <method> [json] - call one easymesh method on another
# box as the mesh user; prints the method's answer (the result object), or
# nothing when the box cannot be reached or refuses.
mesh_rpc_call() {
	local host="$1" method="$2" args="$3" sess
	[ -n "$args" ] || args='{}'
	sess=$(mesh_rpc_session "$host") || return 1
	curl -s --max-time 10 -X POST -H 'Content-Type: application/json' \
		-d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"call\",\"params\":[\"$sess\",\"easymesh\",\"$method\",$args]}" \
		"http://$host/ubus" 2>/dev/null |
		jsonfilter -e '@.result[1]' 2>/dev/null
}

# mesh_set_hostname <host> <almac> <name> - ask the box at <host> to take the
# name, if it is the box with that AL-MAC. 0 = written, 3 = the box at that
# address is somebody else, 1 = no answer.
mesh_set_hostname() {
	local out
	out=$(mesh_rpc_call "$1" set_hostname "{\"almac\":\"$2\",\"name\":\"$3\"}") || return 1
	case "$out" in
	*'"ok":true'*|*'"ok": true'*) return 0 ;;
	*'not this box'*) return 3 ;;
	esac
	return 1
}
