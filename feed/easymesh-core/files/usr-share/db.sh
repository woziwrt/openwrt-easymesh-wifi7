# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# easymesh core - database access.
#
# The only file that knows where the controller database lives. Everything that
# reads it goes through sq/sq1/arr; nothing else opens that path directly.
#
# Contract, measured on hardware 2026-09-05 during an unplanned controller
# crash: this database is AUTHORITATIVE FOR TOPOLOGY - nodes, parents and
# depths were restored into the live model in the same second the daemon
# started, before a single 1905 frame arrived, and matched the radios exactly.
# It is NOT AUTHORITATIVE FOR STATIONS: the sta table held twelve rows for two
# real clients, two of four backhaul rows were wrong and one was missing - and
# a stale row of that kind is what drove the controller into the loop that ate
# 6.2 GB and ended in a watchdog reset.
#
# So: read topology from here. Do not trust station rows without checking the
# radios, and never let one decide that a station is still associated.

DB=/etc/mapc/mapc.db

# -cmd .timeout: map-controller writes the same database, and without a busy
# timeout a query that meets its lock fails at once - and with stderr gone,
# silently. Measured 2026-09-23 on a copy of mapc.db: an INSERT under an
# exclusive lock returned 1 without a word; with the timeout it waited and
# landed. The first store of bh_candidate was lost exactly that way.
sq() { sqlite3 -json -cmd ".timeout 3000" "$DB" "$1" 2>/dev/null; }
sq1() { sqlite3 -cmd ".timeout 3000" "$DB" "$1" 2>/dev/null; }

# JSON array fallback: sqlite3 -json prints nothing for empty result sets
# [] must mean "no rows", never "the query was refused".
#
# sq sends stderr to /dev/null, so a broken query looked exactly like an empty
# table and the caller printed []. On 2026-09-01 a pair of double quotes in an
# SQL comment truncated the nodes query; the Nodes tab was blank for a day and
# nothing anywhere said why. Keep the same output, but say so in the log.
arr() {
	local out rc err
	err=$(mktemp 2>/dev/null || echo /tmp/easymesh-sql.err)
	# Same busy timeout as sq/sq1: without it a read that meets the
	# controller's write lock fails at once, and the page shows an empty
	# topology for one refresh.
	out=$(sqlite3 -json -cmd ".timeout 3000" "$DB" "$1" 2>"$err"); rc=$?
	[ "$rc" -ne 0 ] && logger -t easymesh "SQL refused (rc=$rc): $(head -c 300 "$err")"
	rm -f "$err"
	[ -n "$out" ] && echo "$out" || echo "[]"
}
