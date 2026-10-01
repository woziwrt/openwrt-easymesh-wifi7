# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# /usr/share/easymesh/parent-plan.awk - the decision half of easymesh-parent-plan.
#
# Pure: it reads text lines on stdin and writes the plan on stdout, the new
# state to -v statef and the moves that may be acted on to -v ripef. It never
# touches the database or the network, so the offline harness
# (feed/easymesh-wifi/tests/parent-plan) runs exactly this file.
#
# busybox awk: no 3-argument match(), no gensub/strtonum/asort, no length()
# of an array. Keep it that way.
#
# ---------------------------------------------------------------------------
# THE METRIC: estimated TCP throughput of the WHOLE path to the controller
#
# The old planner counted hops. On 2026-09-27 that sent kitchen and hall
# "2 -> 1 hops" straight onto the controller at -76/-86 dBm, where kitchen's
# backhaul ran at 6 Mbit/s, while under corridor it had 432-720 Mbit/s.
#
# 1. One wireless hop, one leg per band, PHY rate in Mbit/s:
#      measured  - the leg's own median data rate (easymesh-linkstat),
#                  downstream: the backhaul station's rx, what its parent
#                  sends it - clients mostly download, and our legs are far
#                  from symmetric (controller -> hall 126 down, 424 up,
#                  2026-09-27). For every hop ABOVE the node
#                  being planned (its candidates' paths up, and its current
#                  parent's);
#      estimated - from signal via r5()/r6() below, for the node's OWN first
#                  hop, for the current parent and for every candidate alike.
#    The first hop is estimated on both sides on purpose: a measured current
#    leg against an estimated candidate compares two different instruments,
#    and whichever one is more optimistic wins every time - a planner that
#    moves a node and then wants to move it back. Like for like, always.
#
# 2. The two legs of an MLO hop: max + MLO_FRAC * min. Not the sum: on
#    2026-09-25 controller -> hall both radios transmitted ~85 % of the time
#    and together carried 342 Mbit/s; the second radio adds far less than its
#    PHY rate. And card A collapses (368 -> 2 Mbit/s) when its legs are used
#    in opposite directions. The weaker leg counts for a quarter.
#
# 3. PHY -> TCP: EFF (0.35). Measured 2026-09-25: "about a third of the PHY
#    rate arrives as TCP" (0xC8 link rate against iperf3). One factor for
#    every hop, so it scales every path alike and changes no decision; it
#    only makes the printed Mbit/s comparable with iperf3.
#
# 4. A path of k wireless hops: 1 / sum(1 / hop_i). Every node's AP runs on
#    the channels of its own bSTA, so the whole mesh shares one 5 GHz and one
#    6 GHz channel and a relay spends airtime once per hop: two equal hops
#    give half, three a third. It is never above the weakest hop (min) and
#    it is the "each relay hop roughly halves" rule made exact. Measured
#    2026-09-25: controller -> hall -> kitchen on 5 GHz, one hop 342 Mbit/s,
#    two hops 153-172. A wired hop costs nothing.
#
# The path of a node is the path of its parent plus its own hop. Because the
# cost (sum of 1/throughput) is additive, a move that shortens a relay's path
# shortens every path below it by the same amount - the subtree follows.
#
# ---------------------------------------------------------------------------
# RSSI -> PHY RATE (2 spatial streams, 0.8 us GI)
#
# Thresholds: IEEE 802.11ax-2021 Table 27-51 / 802.11be minimum receiver
# sensitivity for 20 MHz (MCS0 -82 ... MCS7 -64 dBm), +3 dB per doubling of
# the bandwidth: +6 dB for 80 MHz (5 GHz), +12 dB for 320 MHz (6 GHz).
# Rates: HE/EHT MCS table, NSS 2 (80 MHz: 72/144/216/288/432/576/648/720;
# 320 MHz: 288/576/864).
# Cap: never more than the best MEDIAN we have measured on a leg of this lab
# - 720 on 5 GHz (kitchen under hall, -46 dBm, 2026-09-26), 864 on 6 GHz
# (kitchen under hall, -68 dBm, same evening). Standard receivers do better
# than the minimum sensitivity, but our 5 GHz legs do worse (432 at -50 dBm,
# a busy channel): the cap keeps the table from promising what no leg here
# has ever held, and makes two strong candidates equal rather than ranking
# them by noise.
# Below MCS0: mt76 falls back to a narrower channel and one stream. Measured
# 36-51 Mbit/s at -78 dBm on 6 GHz (corridor -> kitchen, 2026-09-27) and
# 6 Mbit/s at -76 on 5 GHz (kitchen on the controller, same day). One tier:
# 50 on 6 GHz down to -80, 17 on 5 GHz (MCS0, 2 SS, 20 MHz) down to -82.
#
# Checked against every leg we measured (see tests/parent-plan/calibration):
# 5 GHz -46 -> 720 (meas. 720), -50/-51 -> 720 (meas. 309-432, over),
# 6 GHz -68/-69 -> 288 (meas. 864, under), -78 -> 50 (meas. 36-51).
# ---------------------------------------------------------------------------
#
# Input lines (space separated, one fact per line):
#   ROOT <ctrl-almac>
#   NOW <epoch>
#   N <almac> <agent-age-s>                      a node the controller knows
#   C <child> <parent>                           bstamld: the child's own report
#   W <child> <parent> <agent-age-s>             a wired edge (media type < 0x100)
#   L <child> <band> <state> <rssi> <tx> <rx> <parent|-> <age-s>
#                                                a leg, easymesh-linkstat-collect
#   S <child> <cand> <cand-mld> <band> <signal> <age-s>
#                                                a scan, easymesh-parent-scan
#   X alive <almac> <since>                      previous state
#   X par <child> <parent> <since>
#   X streak <child> <count> <first-ts>
#   hold <child> <parent> <ts>                   that pair tried by hand and not kept,
#                                                or a trial that could not be started
#   deny <child> <parent> <ts>
# band: 2 = 5 GHz, 8 = 6 GHz (libwifi enum wifi_band).

function r5(s) {
	if (s == "" || s + 0 >= 0) return 0
	s += 0
	if (s >= -58) return 720
	if (s >= -59) return 648
	if (s >= -60) return 576
	if (s >= -64) return 432
	if (s >= -68) return 288
	if (s >= -71) return 216
	if (s >= -73) return 144
	if (s >= -76) return 72
	if (s >= -82) return 17
	return 0
}
function r6(s) {
	if (s == "" || s + 0 >= 0) return 0
	s += 0
	if (s >= -65) return 864
	if (s >= -67) return 576
	if (s >= -70) return 288
	if (s >= -80) return 50
	return 0
}
function rate(b, s) { return (b == 8) ? r6(s) : r5(s) }
function mlo(a, b,   hi, lo) {
	hi = (a > b) ? a : b; lo = (a > b) ? b : a
	return hi + mlofrac * lo
}
# PHY Mbit/s -> cost of one hop (1 / TCP Mbit/s); INF for a dead hop
function hopcost(phy) { return (phy > 0) ? 1 / (eff * phy) : INF }
function tput(c) { return (c >= INF) ? 0 : int(1 / c + 0.5) }

# A measured leg, downstream: the rx rate of the backhaul station; a leg that
# carried nothing downstream falls back to its tx rate, an idle one (0/0) to
# its own signal. A leg that is not alive is 0.
function measleg(n, b,   t, r) {
	if (!((n, b) in lst)) return 0
	if (lst[n, b] != "up" && lst[n, b] != "degraded") return 0
	t = ltx[n, b] + 0; r = lrx[n, b] + 0
	if (r > 0) return r
	if (t > 0) return t
	return rate(b, lrssi[n, b])
}

# The signal <n> hears from <p> on band <b>: a fresh scan first, else the
# signal of the leg n holds to p right now.
function sigof(n, p, b) {
	if ((n, p, b) in sig) return sig[n, p, b]
	if (par[n] == p && ((n, b) in lrssi) && lrssi[n, b] < 0) return lrssi[n, b]
	return ""
}
function estphy(n, p) { return mlo(rate(2, sigof(n, p, 2)), rate(8, sigof(n, p, 8))) }
function sigtxt(n, p,   a, b) {
	a = sigof(n, p, 2); b = sigof(n, p, 8)
	return ((a == "") ? "?" : a) "/" ((b == "") ? "?" : b)
}

# Path cost of n to the root over MEASURED hops, and whether the path exists:
# every node on it alive, reaching the root, no loop. Memoised.
function pathcost(n,   p, c, guard, m, chain, i) {
	if (n in pc) return pc[n]
	if (n == root) { pc[n] = 0; conn[n] = 1; dep[n] = 0; return 0 }
	# walk up iteratively, then fold back down
	m = 0; p = n; guard = 0
	while (p != root && !(p in pc)) {
		if ((p in onstack) || guard++ > 16 || !(p in alive) || !(p in par)) {
			for (i = 1; i <= m; i++) { pc[chain[i]] = INF; conn[chain[i]] = 0; dep[chain[i]] = -1; delete onstack[chain[i]] }
			pc[n] = INF; conn[n] = 0; dep[n] = -1
			return INF
		}
		onstack[p] = 1; chain[++m] = p; p = par[p]
	}
	for (i = m; i >= 1; i--) {
		c = chain[i]; delete onstack[c]
		if (!conn[par[c]]) { pc[c] = INF; conn[c] = 0; dep[c] = -1; continue }
		if (c in wired) { pc[c] = pc[par[c]] }
		else { pc[c] = pc[par[c]] + hopcost(mlo(measleg(c, 2), measleg(c, 8))) }
		if (pc[c] > INF) pc[c] = INF
		conn[c] = 1; dep[c] = dep[par[c]] + ((c in wired) ? 0 : 1)
	}
	return pc[n]
}
# Is d below a (in the current tree)?
function isbelow(d, a,   guard) {
	guard = 0
	while (d != "" && d != root && guard++ < 16) {
		if (!(d in par)) return 0
		d = par[d]
		if (d == a) return 1
	}
	return 0
}

BEGIN {
	INF = 1e9
	if (eff == "") eff = 0.35
	if (ghostage == "") ghostage = 3600
	if (mlofrac == "") mlofrac = 0.25
	if (badpath == "") badpath = 100
	if (closer == "") closer = 50
	if (relaycloser == "") relaycloser = 100
}

$1 == "ROOT"  { root = $2; next }
$1 == "NOW"   { now = $2; next }
$1 == "N"     { known[$2] = 1; nage[$2] = $3 + 0; next }
$1 == "C"     { cpar[$2] = $3; known[$2] = 1; next }
$1 == "W"     { wpar[$2] = $3; wage[$2] = $4; known[$2] = 1; next }
$1 == "L" {
	known[$2] = 1
	if ($9 + 0 > linkfresh) next
	alive[$2] = 1; haslegs[$2] = 1
	lst[$2, $3] = $4; lrssi[$2, $3] = $5; ltx[$2, $3] = $6; lrx[$2, $3] = $7
	if ($8 != "-") { lvote[$2, $8]++; if (lvote[$2, $8] > lbest[$2]) { lbest[$2] = lvote[$2, $8]; lpar[$2] = $8 } }
	next
}
$1 == "S" {
	known[$2] = 1
	if ($7 + 0 > maxage) { stale[$2] = 1; next }
	if (!(($2, $3, $5) in sig) || $6 + 0 > sig[$2, $3, $5]) sig[$2, $3, $5] = $6 + 0
	if (!(($2, $3) in heard)) { heard[$2, $3] = 1; cands[$2] = cands[$2] " " $3 }
	mldof[$3] = $4
	next
}
$1 == "X" && $2 == "alive"  { oalive[$3] = $4; next }
$1 == "X" && $2 == "par"    { opar[$3] = $4; opsince[$3] = $5; next }
$1 == "X" && $2 == "streak" { ocnt[$3] = $4; ofirst[$3] = $5; next }
$1 == "hold" { hpair[$2, $3] = $4; next }
$1 == "deny" { deny[$2, $3] = $4; next }

END {
	pc[root] = 0; conn[root] = 1; dep[root] = 0
	# --- who is whose child, who is alive -------------------------------
	for (n in known) {
		if (n == root) continue
		# the node's own fresh legs name its parent best; bstamld may lag
		if (n in lpar) par[n] = lpar[n]
		else if (n in cpar) par[n] = cpar[n]
		else if ((n in wpar) && !(n in haslegs)) {
			par[n] = wpar[n]; wired[n] = 1
			if (wage[n] + 0 <= agentfresh) alive[n] = 1
		}
	}
	for (n in par) kids[par[n]]++
	# stability: since when is a node alive, since when on this parent
	for (n in alive) {
		asince[n] = (n in oalive) ? oalive[n] : now
		printf "X alive %s %d\n", n, asince[n] > statef
	}
	for (n in par) {
		psince[n] = ((n in opar) && opar[n] == par[n]) ? opsince[n] : now
		pwhy[n] = (n in opar) ? "parent changed" : "first seen by the planner"
		printf "X par %s %s %d\n", n, par[n], psince[n] > statef
	}
	for (n in known) if (n != root) pathcost(n)

	moves = 0
	for (n in known) {
		if (n == root || (n in wired)) continue
		cp = (n in par) ? par[n] : "-"
		if (!(n in alive) || !conn[n]) {
			# The agent table keeps every box that ever joined - one that
			# was removed, replaced or paired again under another AL
			# address. Silent after an hour: that is a ghost, not a node
			# in trouble. (The AL address itself is stable across boots.)
			if ((n in nage) && nage[n] > ghostage) continue
			if (!(n in haslegs) && !(n in cpar))
				printf "%s: no action - no backhaul association; waiting for a box in 5/6 GHz range (it scans by itself)\n", n
			else
				printf "%s: no action - no path to the controller right now (%s); the node finds a parent by itself first\n", n, (n in alive) ? "its parent chain does not reach the controller" : "not heard from"
			continue
		}
		cd = dep[n]
		# like for like: the current first hop estimated from signal, as the
		# candidates are
		ce = estphy(n, cp)
		curc = hopcost(ce) + pc[cp]; if (curc > INF) curc = INF
		cur = tput(curc)
		curtxt = sprintf("%s (depth %d, %s dBm, %d Mbit/s)", cp, cd, sigtxt(n, cp), cur)

		if (now - psince[n] < stable) {
			printf "%s: settling on %s - %s %d s ago, planning after %d s\n", n, curtxt, pwhy[n], now - psince[n], stable
			continue
		}
		if (cands[n] == "") {
			printf "%s: keep %s - no fresh scan (%s)\n", n, curtxt, (n in stale) ? "the last one is older than " maxage " s" : "none received"
			continue
		}
		# A scan that did not hear the parent we are on gives no estimate for
		# it: cur would be 0 and every candidate "+999 %" (review, 2026-09-28).
		if (sigof(n, cp, 2) == "" && sigof(n, cp, 8) == "") {
			printf "%s: keep %s - the last scan did not hear the current parent\n", n, curtxt
			continue
		}

		best = ""; bestc = INF; notes = ""
		k = split(cands[n], cl, " ")
		for (i = 1; i <= k; i++) {
			p = cl[i]
			if (p == "" || p == cp) continue
			if (p != root && (!(p in alive) || !conn[p])) { notes = notes sprintf("; %s refused: no path to the controller", p); continue }
			if (isbelow(p, n)) { notes = notes sprintf("; %s refused: it is below %s", p, n); continue }
			if (((n, p) in deny) && now - deny[n, p] < denys) { notes = notes sprintf("; %s refused: trial failed %d s ago", p, now - deny[n, p]); continue }
			# A cooldown per PAIR, and only after a pair that did not
			# work. Until 2026-10-01 it was per node and written by every
			# trial, kept ones and hand ones included: after a relay was
			# moved by hand its children landed on parents at 6 and
			# 3 Mbit/s, and the planner, which saw the right parent at
			# +2000 %, had to wait an hour because of THEIR earlier,
			# successful trials. A kept trial is no evidence against
			# anything.
			if (((n, p) in hpair) && now - hpair[n, p] < cooldown) { notes = notes sprintf("; %s not again yet: tried %d s ago", p, now - hpair[n, p]); continue }
			if (p != root && now - asince[p] < stable) { notes = notes sprintf("; %s not yet: up only %d s", p, now - asince[p]); continue }
			pe = estphy(n, p)
			c = hopcost(pe) + pc[p]; if (c > INF) c = INF
			if (c < bestc) { bestc = c; best = p }
		}
		if (best == "") {
			printf "%s: keep %s - no other usable parent%s\n", n, curtxt, notes
			continue
		}
		bt = tput(bestc)
		bdep = dep[best] + 1
		besttxt = sprintf("%s (depth %d, %s dBm, %d Mbit/s)", best, bdep, sigtxt(n, best), bt)
		need = (n in kids) ? relaygain : gain
		pct = (cur > 0) ? int((bt - cur) * 100 / cur) : 999
		# Two rules, each a plain comparison:
		# A - the path is bad (< badpath) and the best other is `need` better;
		# B - the best other is CLOSER to the controller (fewer hops) and
		#     `cneed` better. B is the picture everyone reads as a broken
		#     mesh: corridor, next to the controller, hanging on hall after a
		#     reboot (2026-09-28), its path fine but far from what it could be.
		#     A parent further out never wins by B: kitchen stays behind hall
		#     even though corridor is one hop closer and +24 %.
		cneed = (n in kids) ? relaycloser : closer
		ruleb = (bdep < cd && bt >= cur * (1 + cneed / 100) && bt - cur >= mingain)
		if (cur >= badpath && !ruleb) {
			printf "%s: keep %s - its path is not bad (>= %d Mbit/s); best other %s is %+d %%%s\n", n, curtxt, badpath, besttxt, pct, notes
			continue
		}
		if (!ruleb && !(bt >= cur * (1 + need / 100) && bt - cur >= mingain)) {
			printf "%s: keep %s - best other %s is %+d %%, needs +%d %% and +%d Mbit/s%s\n", n, curtxt, besttxt, pct, need, mingain, notes
			continue
		}
		# the gain holds: count consecutive runs
		cnt = (n in ocnt) ? ocnt[n] + 1 : 1
		first = (n in ofirst) ? ofirst[n] : now
		printf "X streak %s %d %d\n", n, cnt, first > statef
		# A is the rescue (on by default), B the tidy-up (danger zone)
		rulea = (cur < badpath && bt >= cur * (1 + need / 100) && bt - cur >= mingain)
		why = sprintf("%+d %% path estimate%s", pct, rulea ? "" : ", closer to the controller")
		if (cnt < streak || now - first < hold) {
			printf "%s: wait %s -> %s: %s (seen %d/%d runs, %d s)\n", n, curtxt, besttxt, why, cnt, streak, now - first
			continue
		}
		printf "%s: MOVE %s -> %s: %s (seen %d runs)\n", n, curtxt, besttxt, why, cnt
		printf "%s %s %s %d %d %d %s\n", n, best, mldof[best], cur, bt, pct, (rulea ? "A" : "B") > ripef
		moves++
	}
	printf "# %d move(s) proposed\n", moves
}
