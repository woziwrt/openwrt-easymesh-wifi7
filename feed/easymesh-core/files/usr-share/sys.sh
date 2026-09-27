# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# easymesh core - system state adapter.
#
# What this box is right now: its role, and whether it has been configured at
# all. Reads the system, never the database.

# Whether anyone has ever set this box up, and it cost the wizard its whole
# first-run screen to get wrong. mapcontroller ships enabled='1' from the
# factory - measured 2026-08-17 in /rom/etc/config/mapcontroller - so a box
# straight out of firstboot reported "controller", the setup page answered
# "this box is already set up as controller", and offered nothing but
# Reconfigure. There was no way into the mesh from a brand-new box at all.
#
# What proves a decision was made, without asking what the user called their
# network. Measured 2026-08-17 on three boxes at once - a controller, an agent
# and one straight out of firstboot - and every other candidate failed:
# adopt-state was present on the fresh box, so was mapc.db, and
# controller_select.local was '0' there too because map-agent elects a
# controller on its own when it sees one.
#
# dhcp.lan.ignore is the one mark left. easymesh-role writes it and nothing
# else does: '0' on a controller, '1' on an agent, unset from the factory. It
# also cannot be broken by naming: an earlier version of this checked the
# fronthaul SSID against a list of factory names, which would have silenced the
# mesh of anyone who called their network "OpenWrt-home".
configured() {
	[ -f /etc/mapc/role ] && return 0
	[ -n "$(uci -q get dhcp.lan.ignore)" ] && return 0
	return 1
}

role() {
	if [ -f /etc/mapc/role ]; then
		case "$(cat /etc/mapc/role 2>/dev/null)" in
		controller) echo controller; return ;;
		agent)      echo agent;      return ;;
		esac
	fi

	configured || { echo unconfigured; return; }

	# Configured before the marker existed: dhcp.lan.ignore says which way.
	if [ "$(uci -q get dhcp.lan.ignore)" = "0" ]; then
		echo controller
	else
		echo agent
	fi
}
