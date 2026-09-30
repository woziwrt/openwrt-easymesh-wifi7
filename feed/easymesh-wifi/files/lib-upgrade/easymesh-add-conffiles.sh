# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# /lib/upgrade/easymesh-add-conffiles.sh - what of /etc/mapc a sysupgrade keeps.
#
# Sourced by /sbin/sysupgrade (include /lib/upgrade) before it builds the
# backup; the hook appends to the list of files to keep.
#
# Until 2026-09-30 the whole /etc/mapc/ went into /etc/sysupgrade.conf: the
# database copied while the controller was writing it (main file, -wal and
# -shm taken at different moments), packet captures from failed soft
# restarts, logs that never rotate, and the lab switches (*-live, *-dry) that
# must not follow a box into a new image. Now the list is explicit, and the
# database is folded into one file first.

add_easymesh_conffiles()
{
	local list="$1" f

	# One consistent file instead of three that disagree. The controller
	# keeps writing; a checkpoint moves the WAL into the main file, and the
	# copy is taken right after.
	if [ -f /etc/mapc/mapc.db ] && command -v sqlite3 >/dev/null 2>&1; then
		sqlite3 -cmd ".timeout 5000" /etc/mapc/mapc.db \
			"PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1
	fi

	for f in /etc/mapc/role /etc/mapc/adopt-state /etc/mapc/bh-ssid \
	         /etc/mapc/addr-reservations /etc/mapc/addr-finish.done \
	         /etc/mapc/fh-finish.done /etc/mapc/mapc.db \
	         /etc/mapc/ttlm-policy /etc/mapc/card-suspect /etc/mapc/str-ok \
	         /etc/mapc/join-with-reboot /etc/mapc/join-clean-reboot \
	         /etc/mesh-node-names; do
		[ -f "$f" ] || continue
		grep -qxF "$f" "$list" || echo "$f" >> "$list"
	done
	# The lab's measuring tools (not present on a normal box).
	[ -d /etc/mapc/lab ] && find /etc/mapc/lab -type f >> "$list"
	return 0
}

sysupgrade_init_conffiles="$sysupgrade_init_conffiles add_easymesh_conffiles"
