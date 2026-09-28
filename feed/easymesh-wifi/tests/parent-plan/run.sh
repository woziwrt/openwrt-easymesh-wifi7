#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# Offline test of easymesh-parent-plan: the real script and the real
# parent-plan.awk against a mapc.db built from fixtures/, no radio, no router.
#
#   sh feed/easymesh-wifi/tests/parent-plan/run.sh [-v]
#
# Needs sh, sqlite3, awk, sed, sort - nothing else. Runs on a Mac (BWK awk)
# and on an OpenWrt box or the build VM (busybox awk); the planner has to
# work with both. -v prints every plan, not only the failing ones.
#
# Every case builds a fresh database: schema.sql + fixtures/mesh.sql +
# fixtures/scans.sql + one scenario + a few lines of SQL of its own, then runs
# the planner once or several times with its clock (NOW) moved forward.
# The output is shown with the made-up addresses replaced by box names.

HERE=$(cd "$(dirname "$0")" && pwd)
PKG=$(cd "$HERE/../.." && pwd)
PLAN=$PKG/files/usr-sbin/easymesh-parent-plan
T=$(mktemp -d "${TMPDIR:-/tmp}/parent-plan-test.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT INT TERM
VERBOSE=0; [ "$1" = -v ] && VERBOSE=1
NOW0=1790524800 # 2026-09-27 16:00:00 UTC
CTRL=02:00:00:00:00:01
pass=0; fail=0

# --- stubs: the libraries the planner sources, logger, uci ----------------
mkdir -p "$T/lib" "$T/bin"
cp "$PKG/files/usr-share/parent-plan.awk" "$T/lib/"
: > "$T/lib/db.sh"; : > "$T/lib/names.sh"; : > "$T/lib/rpc.sh"
cat > "$T/bin/logger" <<'EOF'
#!/bin/sh
# logger -t TAG message  ->  "TAG message" appended to $LOGF
[ "$1" = -t ] && { tag=$2; shift 2; }
echo "$tag $*" >> "$LOGF"
EOF
printf '#!/bin/sh\nexit 1\n' > "$T/bin/uci"
chmod +x "$T/bin/logger" "$T/bin/uci"

names() {
	sed -e 's/02:00:00:00:[0-9a-f][0-9a-f]:01/controller/g' \
	    -e 's/02:00:00:00:[0-9a-f][0-9a-f]:02/corridor/g' \
	    -e 's/02:00:00:00:[0-9a-f][0-9a-f]:03/hall/g' \
	    -e 's/02:00:00:00:[0-9a-f][0-9a-f]:04/kitchen/g' \
	    -e 's/02:00:00:00:[0-9a-f][0-9a-f]:05/bedroom/g' \
	    -e 's/02:00:00:00:[0-9a-f][0-9a-f]:06/attic/g'
}

# newcase <title> <scenario.sql> [extra SQL]
newcase() {
	CASE=$1; C=$T/case; rm -rf "$C"; mkdir -p "$C/st" "$C/mem"
	DBF=$C/mapc.db; LOGF=$C/log; : > "$LOGF"; NOW=$NOW0; OUTS=""
	{ cat "$HERE/schema.sql" "$HERE/fixtures/mesh.sql" "$HERE/fixtures/scans.sql"
	  [ -n "$2" ] && cat "$HERE/fixtures/$2"
	  [ -n "$3" ] && echo "$3"
	} | sed "s/@NOW@/$NOW/g" | sqlite3 "$DBF" || echo "!! fixture SQL failed in $CASE"
}
sql() { echo "$1" | sed "s/@NOW@/$NOW/g" | sqlite3 "$DBF"; }
# the clock moves: every leg, scan and agent is as fresh as it was at NOW0
refresh() {
	sql "UPDATE bsta_link SET last_seen = last_seen + $1;
	     UPDATE bh_candidate SET scan_ts = scan_ts + $1;
	     UPDATE agent SET last_seen = last_seen + $1;"
	NOW=$((NOW + $1))
}
# one planner run at NOW; single-run cases need no streak and no settling
plan() {
	env PATH="$T/bin:$PATH" LOGF="$LOGF" NOW="$NOW" PLAN_DB="$DBF" LIBDIR="$T/lib" \
		ROLE=controller CTRL=$CTRL OUT="$C/plan.txt" ST="$C/st" MEM="$C/mem" \
		LIVE="$C/live" KICK="$C/kick" ONESHOT=1 \
		STREAK=${STREAK:-1} HOLD_S=${HOLD_S:-0} STABLE_S=${STABLE_S:-0} \
		sh "$PLAN" 2>&1 | names > "$C/out"
	OUTS="$OUTS
== t+$((NOW - NOW0)) s
$(cat "$C/out")"
}
ok() {
	if [ "$1" = 0 ]; then pass=$((pass + 1)); r=PASS; else fail=$((fail + 1)); r=FAIL; fi
	echo "$r  $CASE: $2"
	[ "$r" = FAIL ] || [ "$VERBOSE" = 1 ] && { echo "$OUTS" | sed 's/^/      /'; echo; }
	OUTS=""
}
has() { grep -q -- "$1" "$C/out"; }

echo "# parent planner, offline - $(awk --version 2>/dev/null | head -1 || echo awk)"
echo

# 0. The table against what we measured. Not a pass/fail: to be read.
echo "# calibration: signal -> PHY estimate (r5/r6) against measured leg medians"
sed -n '/^function r5/,/^function rate(/p' "$PKG/files/usr-share/parent-plan.awk" > "$T/cal.awk"
cat >> "$T/cal.awk" <<'EOF'
BEGIN {
	print "      band  dBm   est  measured  source"
	n = split("2 -46 720 kitchen-under-hall_26.9|2 -50 432 kitchen-under-corridor_26.9|2 -51 309-432 kitchen-under-corridor_A/B_27.9|2 -76 6 kitchen-on-controller_27.9|8 -68 864 kitchen-under-hall_26.9|8 -69 864 kitchen-under-hall_A/B_27.9|8 -78 36-51 kitchen-under-corridor_A/B_27.9|8 -82 103 kitchen-under-corridor_26.9(40MHz,1SS)", p, "|")
	for (i = 1; i <= n; i++) {
		split(p[i], f, " ")
		printf "      %-4s  %4d  %4d  %8s  %s\n", (f[1] == 8 ? "6G" : "5G"), f[2], rate(f[1], f[2]), f[3], f[4]
	}
}
EOF
awk -f "$T/cal.awk" | sed 's/_/ /g'
echo

# 1. The morning of 2026-09-27: kitchen and hall stuck on the controller.
newcase "stuck on the controller (27. 9.)" stuck.sql
plan
has "^kitchen: MOVE controller .* -> corridor " && has "^hall: MOVE controller .* -> corridor " &&
	has "^corridor: keep " && has "^bedroom: keep " && ! has "bedroom: MOVE"
ok $? "kitchen (-76/-86) and hall (-75/-84) go under corridor, corridor and bedroom stay"

# 2. The shape it should leave behind is stable.
newcase "settled" settled.sql
plan
! has ": MOVE " && has "^kitchen: keep corridor" && has "^hall: keep corridor"
ok $? "kitchen and hall under corridor: nothing moves"

# 3. kitchen under hall (26. 9. night): the A/B measured a tie with corridor
#    (133/145 vs 116/182 Mbit/s) - no move either way.
newcase "kitchen under hall" settled.sql "
	UPDATE bstamld SET ap_mld_macaddr = '02:00:00:00:01:03' WHERE agent_almac = '02:00:00:00:00:04';
	INSERT OR REPLACE INTO bsta_link (agent_almac, link_id, band, bssid, state, last_seen, rssi, tx_mbit, rx_mbit) VALUES
	('02:00:00:00:00:04', 0, 2, '02:00:00:00:01:03', 'up', @NOW@ - 20, -45, 648, 516),
	('02:00:00:00:00:04', 1, 8, '02:00:00:00:06:03', 'up', @NOW@ - 20, -69, 864, 864);"
plan
! has "^kitchen: MOVE" && has "^kitchen: keep hall .* its path is not bad"
ok $? "two parents within 30 %: kitchen stays under hall"

# 3b. Only a plainly better parent: kitchen is on the controller (25 Mbit/s,
#     a bad path), but corridor, heard only at -73 dBm on 5 GHz and not on
#     6 GHz, would give about 42 - under twice as much. It stays; hall, with
#     corridor at -42, still goes.
newcase "not twice" stuck.sql "
	UPDATE bh_candidate SET signal = -73 WHERE agent_almac = '02:00:00:00:00:04' AND bssid = '02:00:00:00:01:02';
	DELETE FROM bh_candidate WHERE agent_almac = '02:00:00:00:00:04' AND bssid = '02:00:00:00:06:02';"
plan
! has "^kitchen: MOVE" && has "^kitchen: keep controller .* needs +100 % and +50 Mbit/s" && has "^hall: MOVE .* -> corridor"
ok $? "only a plainly better parent: a bad path and +68 % is not enough, +100 % is"

# 4. No flapping: kitchen under corridor, the scans wobble +-3 dB every run
#    towards hall and back, eight runs, with the real streak and hold.
newcase "wobbling scans" settled.sql
STREAK=3 HOLD_S=120 STABLE_S=0; export STREAK HOLD_S STABLE_S
i=0; moved=0
while [ $i -lt 8 ]; do
	if [ $((i % 2)) = 0 ]; then d=3; else d=-3; fi
	sql "UPDATE bh_candidate SET signal = signal + $d WHERE agent_almac = '02:00:00:00:00:04' AND bssid LIKE '%:03';
	     UPDATE bh_candidate SET signal = signal - $d WHERE agent_almac = '02:00:00:00:00:04' AND bssid LIKE '%:02';"
	plan; has ": MOVE " && moved=1
	refresh 60; i=$((i + 1))
done
unset STREAK HOLD_S STABLE_S
[ $moved = 0 ] && ! grep -q "MOVE" "$LOGF"
ok $? "8 runs of +-3 dB wobble: no move, nothing logged"

# 5. Island: hall and kitchen hold each other up, the controller has not
#    heard them for 15 min (their bstamld rows still exist). bedroom, weak on
#    the controller, hears hall loud - hall must be refused.
newcase "island" stuck.sql "
	UPDATE bstamld SET ap_mld_macaddr = '02:00:00:00:01:04' WHERE agent_almac = '02:00:00:00:00:03';
	UPDATE bstamld SET ap_mld_macaddr = '02:00:00:00:01:03' WHERE agent_almac = '02:00:00:00:00:04';
	UPDATE bsta_link SET last_seen = @NOW@ - 900 WHERE agent_almac IN ('02:00:00:00:00:03', '02:00:00:00:00:04');
	UPDATE bsta_link SET rssi = -70, tx_mbit = 144, rx_mbit = 144 WHERE agent_almac = '02:00:00:00:00:05' AND link_id = 0;
	UPDATE bsta_link SET rssi = -80, tx_mbit = 0, rx_mbit = 0, state = 'down' WHERE agent_almac = '02:00:00:00:00:05' AND link_id = 1;
	DELETE FROM bh_candidate WHERE agent_almac = '02:00:00:00:00:05';
	INSERT INTO bh_candidate (agent_almac, bssid, freq, signal, scan_ts) VALUES
	('02:00:00:00:00:05', '02:00:00:00:01:01', 5180, -70, @NOW@ - 120),
	('02:00:00:00:00:05', '02:00:00:00:06:01', 6135, -80, @NOW@ - 120),
	('02:00:00:00:00:05', '02:00:00:00:01:03', 5180, -45, @NOW@ - 120),
	('02:00:00:00:00:05', '02:00:00:00:06:03', 6135, -60, @NOW@ - 120);"
plan
! has "^bedroom: MOVE" && has "^bedroom: keep .*hall refused: no path to the controller" &&
	has "^hall: no action - no path" && has "^kitchen: no action - no path"
ok $? "a parent in an island is refused; the island nodes are left to heal themselves"

# 5b. The same island, but both still answer linkstat (fresh legs) while
#     their parents point at each other: a loop is no path either.
newcase "loop" stuck.sql "
	UPDATE bsta_link SET bssid = '02:00:00:00:01:04' WHERE agent_almac = '02:00:00:00:00:03' AND link_id = 0;
	UPDATE bsta_link SET bssid = '02:00:00:00:06:04' WHERE agent_almac = '02:00:00:00:00:03' AND link_id = 1;
	UPDATE bsta_link SET bssid = '02:00:00:00:01:03' WHERE agent_almac = '02:00:00:00:00:04' AND link_id = 0;
	UPDATE bsta_link SET bssid = '02:00:00:00:06:03' WHERE agent_almac = '02:00:00:00:00:04' AND link_id = 1;
	UPDATE bsta_link SET rssi = -70, tx_mbit = 144, rx_mbit = 144 WHERE agent_almac = '02:00:00:00:00:05' AND link_id = 0;
	INSERT OR REPLACE INTO bh_candidate (agent_almac, bssid, freq, signal, scan_ts) VALUES
	('02:00:00:00:00:05', '02:00:00:00:01:01', 5180, -70, @NOW@ - 120),
	('02:00:00:00:00:05', '02:00:00:00:01:03', 5180, -45, @NOW@ - 120),
	('02:00:00:00:00:05', '02:00:00:00:06:03', 6135, -60, @NOW@ - 120);"
plan
! has "bedroom: MOVE .* -> hall" && has "hall refused: no path" &&
	has "^hall: no action - no path to the controller right now (its parent chain"
ok $? "parents pointing at each other: no path, refused"

# 6. Orphans: attic is paired but has no backhaul at all; bedroom's last
#    scan is 33 min old.
newcase "orphans" stuck.sql "
	UPDATE bh_candidate SET scan_ts = @NOW@ - 2000 WHERE agent_almac = '02:00:00:00:00:05';"
plan
has "^attic: no action - no backhaul association" && has "^bedroom: keep .* no fresh scan" &&
	! has "attic: MOVE" && ! has "bedroom: MOVE"
ok $? "no candidate -> no action"

# 7. Never under its own child: corridor is weak on the controller and hears
#    hall (its child) at -40. Its path is not bad enough to move, and a
#    relay with two children would need +200 % anyway.
newcase "descendant" settled.sql "
	UPDATE bsta_link SET rssi = -70, tx_mbit = 216, rx_mbit = 144 WHERE agent_almac = '02:00:00:00:00:02' AND link_id = 0;
	UPDATE bsta_link SET rssi = -85, tx_mbit = 0, rx_mbit = 0, state = 'down' WHERE agent_almac = '02:00:00:00:00:02' AND link_id = 1;
	UPDATE bh_candidate SET signal = -70 WHERE agent_almac = '02:00:00:00:00:02' AND bssid = '02:00:00:00:01:01';
	UPDATE bh_candidate SET signal = -85 WHERE agent_almac = '02:00:00:00:00:02' AND bssid = '02:00:00:00:06:01';
	UPDATE bh_candidate SET signal = -40 WHERE agent_almac = '02:00:00:00:00:02' AND bssid = '02:00:00:00:01:03';
	UPDATE bh_candidate SET signal = -55 WHERE agent_almac = '02:00:00:00:00:02' AND bssid = '02:00:00:00:06:03';"
plan
! has "^corridor: MOVE" && has "hall refused: it is below corridor" && has "kitchen refused: it is below corridor"
ok $? "a node below is never a parent; a relay is not moved for a small gain"

# 8. A failed trial denies that parent for 24 h - the next best is judged
#    on its own (hall, itself on the controller, pays too little).
newcase "deny" stuck.sql
echo $((NOW0 - 3600)) > "$C/mem/deny.02:00:00:00:00:04.02:00:00:00:00:02"
plan
! has "kitchen: MOVE .* -> corridor" && has "^kitchen: .*corridor refused: trial failed 3600 s ago"
ok $? "denied parent is not proposed again within 24 h"

# 9. Cooldown after a trial.
newcase "cooldown" stuck.sql
echo $((NOW0 - 600)) > "$C/mem/last.02:00:00:00:00:04"
plan
has "^kitchen: hold controller .* -> corridor .* cooldown, last trial 600 s ago" && ! has "^kitchen: MOVE"
ok $? "no second move within the cooldown"

# 10. corridor comes back after a power cut; kitchen and hall saved
#     themselves onto the controller long ago. With the real STABLE_S,
#     STREAK and HOLD_S: nothing before corridor has been up 300 s, a move
#     three runs later, logged once.
newcase "a box returns" stuck.sql
for n in 03 04 05; do
	echo "alive 02:00:00:00:00:$n $((NOW0 - 3600))" >> "$C/st/state"
	echo "par 02:00:00:00:00:$n 02:00:00:00:00:01 $((NOW0 - 3600))" >> "$C/st/state"
done
echo "alive 02:00:00:00:00:02 $NOW0" >> "$C/st/state"
echo "par 02:00:00:00:00:02 02:00:00:00:00:01 $NOW0" >> "$C/st/state"
STREAK=3 HOLD_S=120 STABLE_S=300; export STREAK HOLD_S STABLE_S
first=""; early=0; t=0
while [ $t -le 600 ]; do
	plan
	if has "^kitchen: MOVE .* -> corridor"; then
		[ -z "$first" ] && first=$t
		[ $t -lt 300 ] && early=1
	fi
	refresh 60; t=$((t + 60))
done
unset STREAK HOLD_S STABLE_S
nlog=$(names < "$LOGF" | grep -c "would kitchen: MOVE")
echo "      first MOVE for kitchen at t+${first:-never} s, logged $nlog x"
[ "$early" = 0 ] && [ -n "$first" ] && [ "$first" -ge 300 ] && [ "$nlog" = 1 ]
ok $? "children return only after the box is stable, after the streak, logged once"

# 11. First aid, then optimise: kitchen re-attached by itself a minute ago -
#     the planner lets it settle before judging it.
newcase "first aid" stuck.sql
echo "par 02:00:00:00:00:04 02:00:00:00:00:02 $((NOW0 - 3600))" >> "$C/st/state"
STABLE_S=300; export STABLE_S
plan
unset STABLE_S
has "^kitchen: settling on controller .* parent changed 0 s ago" && ! has "^kitchen: MOVE" &&
	has "^hall: settling .* first seen by the planner"
ok $? "a node that just re-attached is left alone for STABLE_S"

# 11b. A box that rebooted leaves its old AL address in the agent table: a
#      ghost is not reported as a node in trouble.
newcase "ghost" stuck.sql "
	INSERT INTO agent VALUES ('02:00:00:00:00:07', @NOW@ - 7200);
	INSERT INTO bstamld VALUES ('02:00:00:00:0b:07', '02:00:00:00:00:07', '02:00:00:00:01:01');"
plan
! grep -q "02:00:00:00:00:07" "$C/out"
ok $? "an AL address unheard for over an hour is left out"

# 11c. The event trigger, in real time (~6 s): the loop plans once, then
#      only every PERIOD (100 s here) - unless the mesh changes. bedroom
#      vanishes after 3 s; the plan must say so before the period is up.
newcase "event trigger" stuck.sql
NOW=$(date +%s); refresh 0
sql "UPDATE bsta_link SET last_seen = @NOW@ - 5; UPDATE bh_candidate SET scan_ts = @NOW@ - 60; UPDATE agent SET last_seen = @NOW@ - 5;"
env PATH="$T/bin:$PATH" LOGF="$LOGF" PLAN_DB="$DBF" LIBDIR="$T/lib" \
	ROLE=controller CTRL=$CTRL OUT="$C/plan.txt" ST="$C/st" MEM="$C/mem" \
	LIVE="$C/live" KICK="$C/kick" TICK=1 SETTLE_S=2 STABLE_S=0 STREAK=1 HOLD_S=0 \
	sh "$PLAN" 100 > /dev/null 2>&1 &
bg=$!
sleep 3
grep -q "02:00:00:00:00:05: keep" "$C/plan.txt" 2>/dev/null; before=$?
sql "UPDATE bsta_link SET last_seen = 0 WHERE agent_almac = '02:00:00:00:00:05';"
sleep 3
kill "$bg" 2>/dev/null; wait "$bg" 2>/dev/null
names < "$C/plan.txt" > "$C/out"; OUTS=$(cat "$C/out")
[ "$before" = 0 ] && has "^bedroom: no action - no path"
ok $? "a node that vanishes is replanned within a tick, not after PERIOD"

# 12. The events page still reads the line (busybox-safe split, as in the API)
newcase "events parser" stuck.sql
plan
line=$(grep "^kitchen: MOVE" "$C/out")
echo "would $line" | awk '
	function idx(w, n_, key,  i) { for (i = 1; i <= n_; i++) if (w[i] == key) return i; return 0 }
	{ wk = split($0, ww, /[ (),]+/); wm = idx(ww, wk, "MOVE"); wj = idx(ww, wk, "->")
	  print ww[1], ww[2], ww[wm + 1], ww[wm + 3], ww[wm + 6], ww[wm + 7], ww[wj + 1], ww[wj + 3], ww[wj + 6], ww[wj + 7] }' > "$C/ev"
OUTS="$line
-> $(cat "$C/ev")"
grep -q "^would kitchen: controller 1 [0-9]* Mbit/s corridor 2 [0-9]* Mbit/s$" "$C/ev"
ok $? "MOVE line keeps the positions the Events parser reads"

echo
echo "# $pass passed, $fail failed"
[ "$fail" = 0 ]
