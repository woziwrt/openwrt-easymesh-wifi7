# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# in_boot_window - is this a boot, or a package operation on a live node?
#
# Sourced by the parts of this package that are only ever meant to act while
# the node is coming up: the first-boot uci-defaults, and the AP-MLD link
# recovery. Each of them already said "runs once per boot" in its own header.
# None of them enforced it, because for a long time boot was the only way they
# could be reached.
#
# It is not the only way. base-files default_postinst (lib/functions.sh) runs,
# on a live system, every /etc/uci-defaults/ file the package ships and then
# "start" on every /etc/init.d/ script it ships. Upgrade behaves exactly like
# install here: PKG_UPGRADE=1 suppresses "enable", not "start". So an
# `apk upgrade` replays first-boot configuration against a node that is
# carrying mesh traffic.
#
# Measured 2026-08-08 on a BPI-R4 (4 GB) node: a routine package upgrade re-ran the
# fronthaul cleanup and restarted mld-link-check, which took the radios down
# and wedged the MT7996 MCU. The node was gone for 25 minutes.
#
# The window is deliberately generous. uci-defaults run from /etc/init.d/boot,
# tens of seconds in. The latest honest caller is mld-link-check at START=98
# plus its 45 s settle, which lands a few minutes in even on the slow first
# boot after a flash. Ten minutes clears all of them and is still far short of
# any node old enough to be worth protecting.
EASYMESH_BOOT_WINDOW=600

# No /proc/uptime means we cannot tell, and the two failure modes are not
# symmetric: guessing "boot" restores the behaviour this file changed, while
# guessing "not boot" would silently skip first-boot configuration and leave a
# node that looks installed and is not. Guess boot.
in_boot_window() {
	local up
	up="$(cut -d. -f1 /proc/uptime 2>/dev/null)"
	[ -n "$up" ] || return 0
	[ "$up" -lt "$EASYMESH_BOOT_WINDOW" ] 2>/dev/null
}

# is_mesh_node - has anyone actually made this box part of a mesh?
#
# Everything in this package assumes one. On a router nobody has onboarded every
# service here is wrong, and one of them is destructive: drop-legacy-fronthaul
# deletes the per-radio networks the board ships with, because it sees an AP-MLD
# section and concludes the fronthaul has moved there. That section is factory -
# mac80211.uc generates it as MT76_AP_MLD on any MLO-capable board.
#
# Measured 2026-08-17 on a freshly flashed production image with no role at all:
#
#     S18drop-legacy-fronthaul: removing default_radio0 (ssid=OpenWrt-2g)
#     S18drop-legacy-fronthaul: removing default_radio1 (ssid=OpenWrt-5g)
#     S18drop-legacy-fronthaul: removing default_radio2 (ssid=OpenWrt-6g)
#
# leaving the owner with one network out of four and no idea why.
#
# The answer is /etc/mapc/role, which easymesh-role writes before it touches
# anything else, or /etc/easymesh-wps-pending while a join is in flight. Nodes
# configured before that marker existed are given it by 88-easymesh-role-marker.
#
# 🔑 Deliberately NOT dhcp.lan.ignore. easymesh-dhcp-safe writes that on every box
# that is not a controller, factory ones included, so it never distinguished
# anything - and three builds shipped with gates resting on it, each failure
# looking like a different missing caller. A mark means "someone decided" only if
# nothing but a decision can produce it.
#
# ⚠️ The mark alone is not enough, and this is what it cost to learn.
#
# base-files default_postinst runs `start` on every init script a package ships,
# on upgrade as well as install. For a procd service `start` is not a harmless
# no-op: rc.common wraps start_service in procd_open_service/procd_close_service,
# and closing a service drops every instance that did not re-register during that
# call. So a start_service that returns early because this test said "factory"
# does not decline to start - it STOPS a service that is running.
#
# And the fleet answers "factory" honestly: the nodes carrying mesh traffic today
# were configured before /etc/mapc/role existed. The file is written by
# 88-easymesh-role-marker, which ships in easymesh-config - and apk configures
# easymesh-wifi FIRST, because easymesh-config depends on it. There is a window,
# during every upgrade, where this package's own services ask the question and the
# answer has not been written yet.
#
# So the test cannot rest on the mark alone. It also asks the question 88 asks,
# from the same code, and that is the point of configured_mesh_role() below: one
# definition, used by the gates and by the script that writes the mark. Three
# gates were built on three private copies of "what counts as a mesh node" and
# each of them was wrong in its own way.
is_mesh_node() {
	[ -f /etc/mapc/role ] && return 0
	[ -f /etc/easymesh-wps-pending ] && return 0
	[ -n "$(configured_mesh_role)" ]
}

# configured_mesh_role - what this box already is, judged from its configuration.
#
# Prints 'controller', 'agent', or nothing at all. Used by
# 88-easymesh-role-marker to write the mark, and by is_mesh_node above to survive
# the window before it is written.
#
# 🔑 Only values the factory cannot produce count here.
#
# A controller says so in two places at once, and easymesh-role is the only thing
# that ever writes that pair. An agent is known by a backhaul key that is not the
# fallback from 99-mapcntlr - the factory derives '1234567890' from an empty
# get_mac_label, and a node that has joined a mesh carries the controller's real
# one. Everything else about a configured node - mapagent.@controller_select,
# dhcp.lan.ignore - is also shipped by the factory, and gates built on those two
# spent three builds declaring untouched routers to be mesh nodes.
EASYMESH_FACTORY_KEY=${EASYMESH_FACTORY_KEY:-1234567890}
configured_mesh_role() {
	local i key

	[ "$(uci -q get mapcontroller.controller.enabled)" = "1" ] &&
		[ "$(uci -q get dhcp.lan.ignore)" = "0" ] && { echo controller; return 0; }

	i=0
	while uci -q get "mapagent.@ap[$i]" >/dev/null 2>&1; do
		if [ "$(uci -q get "mapagent.@ap[$i].type")" = "backhaul" ]; then
			key=$(uci -q get "mapagent.@ap[$i].key")
			[ -n "$key" ] && [ "$key" != "$EASYMESH_FACTORY_KEY" ] && {
				echo agent; return 0
			}
		fi
		i=$((i + 1))
	done
	return 0
}
