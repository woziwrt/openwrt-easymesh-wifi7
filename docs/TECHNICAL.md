# Technical overview

For people who know Wi-Fi 7 MLO or EasyMesh and want to know what exactly happens. The user-facing README is one level
up.

## Architecture

```
            ┌──────────────────────── controller (main box) ────────────────────────┐
            │ map-controller (iopsys + our patches) ── SQLite DB (/etc/mapc/mapc.db) │
            │ easymesh-ttlm-policy  ── decides the TTLM map per backhaul station     │
            │ mesh-gwd (gateway VIP), easymesh-card-check, easymesh API (ubus), LuCI │
            └───────────────┬──────────────────────────────────────────┬─────────────┘
                 IEEE 1905 CMDUs over the backhaul            same, one more hop
            ┌───────────────▼─────────────┐                ┌───────────▼─────────────┐
            │ agent: map-agent, ieee1905,  │  MLO backhaul  │ agent …                 │
            │ wifimngr, hostapd, mt76      │ ◄────5+6 GHz──►│                         │
            └──────────────────────────────┘                └─────────────────────────┘
```

- **Radios:** MT7988A SoC + MT7996 (BE14) tri-band card. Fronthaul and backhaul are AP MLDs. Each agent's backhaul
  station is a 4-address STA MLD with one link on 5 GHz and one on 6 GHz (2.4 GHz is kept for clients).
- **EasyMesh stack:** iopsys `ieee1905` / `map-controller` / `map-agent` / `wifimngr` / `libwifi`, built as EasyMesh R6
  with Profile 3 capabilities reported (Wi-Fi 7 and MLD reports need them). DPP and 1905 message security are not built
  (`USE_LIBDPP` off). See *Deviations*.
- **Persistence:** the controller writes topology, links, stations and metrics into SQLite. After a restart it does not
  start blind, and the API and LuCI read from the database, not from a live snapshot.

## TTLM from the controller

The TTLM mechanism in the driver and hostapd is MediaTek's: mt76 patch `0073-mtk-mt76-mt7996-add-TTLM-support`
(Michael-CY Lee), plus the corresponding mac80211 and hostapd patches in the MediaTek feed. What we add is the part that
decides and delivers:

1. **Decide:** `easymesh-ttlm-policy` runs on the controller. It reads the topology and per-link state from the database
   and writes one line per backhaul station: parent, AP MLD, station MLD, and the TID→link map.
   - *Rule 1, avoid a bad link:* a link is called bad only with evidence in the data (`tx_failed` ≥ 5, or rx stalled
     while the other link carries traffic). Beacon loss alone is not enough, because short 6 GHz beacon gaps on some
     cards do not stop data.
   - *Rule 2, alternate bands across a repeater:* a relaying box receives from its parent on one band and sends to its
     children on the other. It relies on the card doing STR (simultaneous transmit/receive). Measured across one repeater
     (2 hops, downloads): 153 → 260 Mbit/s (+70 %). The upload direction (receive 6, send 5) is not measured yet. Run-to-run variance on our lab is about 30 %, so more A/B runs are pending.
   - Both rules are **dry runs** unless switched on. A dry run logs what it would do.
2. **Deliver:** map-controller sends the map to the parent agent in a **Service Prioritization Request (CMDU `0x8023`)**.
   Riding on an existing CMDU means we inherit its retry logic, and the map survives a controller restart.
3. **Apply:** map-agent on the parent hands the map to hostapd. hostapd negotiates it with the station
   (**Negotiated TTLM**, TTLM Request/Response action frames), and the firmware enforces it.
   Advertised TTLM (per AP) is not used. It must never be mixed with Negotiated TTLM on one AP.

Measured on hardware (2026-09-23): a map "all TIDs on 6 GHz" for one backhaul station → 0 bytes on the 5 GHz link in
**both** directions; setup and teardown 20/20.

## Verifying the claim

Everything here can be checked with two boxes, `tcpdump` and Wireshark. You do not need to trust our logs.

1. **On the wire:** `tcpdump -i <backhaul bridge> -w 1905.pcap ether proto 0x893a` on the parent. You will see the
   Service Prioritization Request (`0x8023`) arrive from the controller.
2. **In the air:** a monitor-mode capture on the backhaul channel shows the protected EHT action frames *TTLM Request* /
   *TTLM Response* between the parent AP MLD and the station, with the same map.
3. **In the traffic:** run `iperf3` through the link. Before the map both links carry bytes. After it, only the mapped
   one does. ⚠️ Read **received** bytes at the other end: per-link *transmit* counters on this platform are not reliable.

## Network layout of a box

- **`br-lan` is the mesh.** The backhaul (MLO station and 4-address AP links) and the fronthaul APs join `br-lan`,
  together with every LAN socket except one. One L2 domain across the whole mesh, STP on (a cable between two boxes is a
  loop), the controller has bridge priority 4096 so it is always the root.
- **One socket is carved out as the service port** (`network.mgmt`): `lan3` on the BPI-R4, `mxl_lan0` (labelled LAN1)
  on the BPI-R4 Pro 8X. Static `192.168.1.1/24`, no gateway, no DNS, DHCP explicitly off (`dhcp.mgmt.ignore=1`), in the
  `lan` firewall zone. The same address can live on every box only because this socket is **not** in the mesh; the
  price is that it answers on exactly one socket. Chosen by board in `easymesh-role` (`default_mgmt_port`); an unknown
  board falls back to `lan3` and refuses to continue if that socket does not exist.
- **The way out is a virtual address**, `.253`/`.254` of the mesh subnet, held by `mesh-gwd` on whichever box has a
  working uplink. Agents point their default route and DNS at it, never at a fixed box.
- Boxes are told apart by hostname and role (`/etc/mapc/role`), never by `192.168.1.1`.

## Mesh services (ours)

| Service | What it does |
|---|---|
| `easymesh-wps-join` / setup | one-button join without reboot: takes the backhaul credentials over WPS, brings up the MLO backhaul station, names the box, falls back to one guarded reboot only if the soft path fails |
| `mesh-gwd` | one virtual gateway address for all clients; any box with a cable (*primary*) or LTE (*backup*) can hold it; releases it at once on carrier loss (client outage ~11 s) |
| `beacon-kick`, link watchdogs | re-arm a backhaul BSS that stopped beaconing after a reconfiguration; record the per-link beacon share |
| `easymesh-card-check` | compares each radio's noise (ANPI from AP Metrics) with the other boxes on the same channel, over one hour; ≥ 6 dB above = suspect card |
| `easymesh-ttlm-policy` | the TTLM decisions above |
| API + LuCI | `ubus call easymesh …` (topology, clients, health, ttlm_state, events, …) and the 8 LuCI tabs |

## Self-healing and optimisation

Everything that can move a box costs connectivity for a moment, so the rule is: the mesh repairs what is broken by
itself, and optimises only when the user asks for it.

- **Joining a parent** is wpa_supplicant's own choice: the backhaul station joins the best BSS carrying the backhaul
  SSID it hears. After a restart the resulting tree follows the radio, not the floor plan.
- **No island (patch `0277`).** A node whose backhaul station loses its parent closes its backhaul BSS at once
  (Authentication refused with status 17) and drops the backhaul stations it had after 1 s, so its children cannot join
  each other or come back to it; the fronthaul keeps running for 20 s while it looks for a new parent. A wired uplink
  counts as a backhaul.
- **Bridges follow a moved box (`easymesh-fdb-guard`).** When a node's backhaul parent or the controller's topology
  changes, the learned bridge entries are flushed on the node, and from the controller on every node - a bridge with
  offload does not relearn a moved MAC for ~300 s.
- **Stuck-box rescue (`easymesh-bh-rescue`, on).** On an agent: if at least 6 of the last 9 pings to the controller
  (one per 10 s) are lost and the last parent scan heard a parent of our own mesh, not below us, at least 10 dB
  stronger, the node moves there with `easymesh-bh-trial` (no measurement) and goes back if the controller cannot be
  reached from there. Never within 5 min of boot or 2 min of a parent change, at most once per 10 min; a target that
  could not carry us is not tried again for an hour.
- **Parent planner (`easymesh-parent-plan`).** On the controller, every 5 min, from the database. Rule A, the
  rescue, is on by default (`/etc/mapc/parent-rescue-off` switches it off): the path is bad (estimated under
  100 Mbit/s) and another parent is at least twice as good. Rule B, the danger zone, is off by default
  (`/etc/mapc/parent-steer-live` switches it on): a parent one hop closer to the controller is at least 1.5 times as
  good. A proposal must hold for 3 runs after 5 min of stability; then one measured trial (iperf3 to the controller,
  3 x 10 s each way, before and after); kept only if no direction lost more than 10 % and one gained at least 20 %,
  otherwise the node goes back by itself. At most one trial in the mesh; a pair that failed waits an hour, and a pair
  whose automatic trial failed is denied for 24 h. Estimates of a node's own first hop come from signal and can be far
  off on a noisy card. The formulas, and why it cannot oscillate:
  [Choosing the parent: the math](#choosing-the-parent-the-math).
- **Missing backhaul link (`mld-bsta-relink`).** A backhaul MLD that came up on fewer links than configured is logged,
  not reconnected: a reassociation - even to the same parent - took the node and its subtree off the mesh for up to
  90 s in our tests, and an unpinned one can pick the node's own child as its parent (a loop).

## Choosing the parent: the math

This is what `easymesh-parent-plan` computes (`/usr/share/easymesh/parent-plan.awk`, run offline by
`feed/easymesh-wifi/tests/parent-plan/run.sh`), written down as formulas. The constants are the defaults of the script;
every one of them can be overridden from the environment. The last part is the planner we intend to build next, marked
as such.

### 1. One hop

A backhaul hop has one leg per band. From the signal $s$ (dBm) a leg gets a PHY rate (Mbit/s, two spatial streams,
80 MHz on 5 GHz, 320 MHz on 6 GHz). The thresholds are the minimum receiver sensitivities of IEEE 802.11ax/be, +3 dB per
doubling of the bandwidth, capped at the best median we ever measured on a leg of the lab:

| $s$ (5 GHz) | ≥ −58 | ≥ −59 | ≥ −60 | ≥ −64 | ≥ −68 | ≥ −71 | ≥ −73 | ≥ −76 | ≥ −82 | below |
|---|---|---|---|---|---|---|---|---|---|---|
| $R_5(s)$ | 720 | 648 | 576 | 432 | 288 | 216 | 144 | 72 | 17 | 0 |

| $s$ (6 GHz) | ≥ −65 | ≥ −67 | ≥ −70 | ≥ −80 | below |
|---|---|---|---|---|---|
| $R_6(s)$ | 864 | 576 | 288 | 50 | 0 |

The two legs of an MLO hop do not add up: both radios share the time of one station, and the weaker one adds about a
quarter of its rate (measured 2026-09-25). The TCP throughput of the hop is a fixed fraction of that:

```math
P(v,p) = \max(R_5, R_6) + \mu \cdot \min(R_5, R_6), \qquad
T(v,p) = \eta \cdot P(v,p), \qquad \mu = 0.25,\ \eta = 0.35
```

$\eta$ scales every hop alike and changes no decision; it only makes the numbers comparable with iperf3. A wired hop
has $T = \infty$.

### 2. A path

Every box runs its access point on the channels of its own backhaul station, so the whole mesh shares one 5 GHz and
one 6 GHz channel. A relay sends every bit once per hop, so what adds up along a path is **airtime per bit**, not
throughput. The cost of a hop is $c = 1/T$, and for a node $v$ with parent $p(v)$:

```math
C(\text{root}) = 0, \qquad C(v) = C\big(p(v)\big) + \frac{1}{T\big(v, p(v)\big)}, \qquad
\widehat{T}(v) = \frac{1}{C(v)}
```

So $\widehat{T}(v)$ is the harmonic composition of the hops: never above the weakest hop, two equal hops give half,
three a third (measured: one hop 342 Mbit/s, two hops 153-172, 2026-09-25). Two properties follow directly and the
planner relies on both:

- **The subtree follows.** If a relay $v$ moves and its cost changes by $\Delta$, the cost of every node below it
  changes by exactly the same $\Delta$. A move is judged on $v$ alone, and its children get the same gain for free.
- **Like for like.** The hops *above* the node are the measured medians of their legs (`easymesh-linkstat`, the
  backhaul station's receive rate). The node's **own** first hop is estimated from the signal for the current parent
  and for every candidate alike. Comparing a measured current leg with an estimated candidate would let the more
  optimistic instrument win every time - a planner that moves a node and then wants it back.

### 3. Today's decision (rules A and B)

For a node $v$ at depth $d(v)$ on parent $p$, every candidate $q$ it heard in its last scan is admissible only if $q$
reaches the root, is not in the subtree of $v$ (no loop), has been up for 300 s, and the pair $(v,q)$ is neither in
cooldown (1 h after a failed trial) nor denied (24 h). Then

```math
T_{\text{cur}} = \frac{1}{\hat c(v,p) + C(p)}, \qquad
q^\ast = \arg\min_{q} \big(\hat c(v,q) + C(q)\big), \qquad
T^\ast = \frac{1}{\hat c(v,q^\ast) + C(q^\ast)}
```

where $\hat c$ is the cost of the estimated first hop. With $g$ the required gain (1 for a leaf, 2 for a relay - a
relay carries others), $g'$ the gain for a closer parent (0.5 leaf, 1 relay) and $m = 50$ Mbit/s:

```math
\textbf{A (rescue, on by default):}\quad T_{\text{cur}} < 100 \ \wedge\ T^\ast \ge (1+g)\,T_{\text{cur}} \ \wedge\ T^\ast - T_{\text{cur}} \ge m
```
```math
\textbf{B (closer, danger zone):}\quad d(q^\ast) + 1 < d(v) \ \wedge\ T^\ast \ge (1+g')\,T_{\text{cur}} \ \wedge\ T^\ast - T_{\text{cur}} \ge m
```

A proposal is acted on only after it held in 3 consecutive runs (one run per 5 min) spanning at least 120 s, with $v$
on its parent for at least 300 s, and at most one trial runs in the mesh at a time. The trial is measured, not
estimated: iperf3 to the controller, the mean of 3 x 10 s each way, before ($u_0, d_0$) and after ($u_1, d_1$) the
move. The move is kept if and only if

```math
u_1 \ge 0.9\,u_0 \ \wedge\ d_1 \ge 0.9\,d_0 \ \wedge\ \big(u_1 \ge 1.2\,u_0 \ \vee\ d_1 \ge 1.2\,d_0\big)
```

and otherwise the node goes back by itself.

**Why it does not oscillate.** Take the costs as fixed for a moment and define the potential of a tree

```math
\Phi = \sum_{v} C(v)
```

Every move that rule A or B accepts lowers $C(v)$ by some $\Delta > 0$ (both demand $T^\ast > T_{\text{cur}}$), and by
the subtree property it lowers the cost of each of the $|S(v)|$ nodes below $v$ by the same $\Delta$, and changes no
other node. So every move lowers $\Phi$ by $\Delta\,(1 + |S(v)|) > 0$. There are finitely many trees and $\Phi$ only
goes down, therefore the sequence of moves is finite: with fixed costs the planner always stops, in a tree where no
node has a parent better by the required margin. The margins (at least ×2 for a rescue, ×3 for a relay) make the reverse
move impossible on the same estimates: it would need $T_{\text{cur}} \ge 2\,T^\ast$ and $T^\ast \ge 2\,T_{\text{cur}}$
at once.

The costs are not fixed in reality - a signal moves by several dB in a minute and the estimate with it. That is what
the streak, the measured verdict, the cooldown and the 24 h deny are for: they bound how often a noisy estimate can
cost a move, they do not make the estimate right. On a noisy card the estimate of the first hop can be far off
(see *Measurements*), and the measured trial is the only judge.

### 4. Planned: the planner as a graph problem

Not in this release. Today the planner looks at one node at a time and fixes what is plainly wrong. The next one
looks at the whole mesh at once.

Let $G = (V, E)$ be the graph of every box and every parent each box can hear, with the weight of an edge
$w(v,q) = 1/T(v,q)$: measured where the pair has carried traffic, estimated from the signal where it has not. Because
the cost of a path is a sum of non-negative weights, there is **one** tree that gives every node its cheapest path to
the root at the same time - the shortest-path tree, found by Dijkstra's algorithm in $O(|E| + |V| \log |V|)$:

```math
C^\ast(v) = \min_{q \,:\, (v,q) \in E} \big( w(v,q) + C^\ast(q) \big), \qquad C^\ast(\text{root}) = 0
```

In the language of graph theory: the mesh is a directed graph - an edge $v \to q$ means $v$ hears $q$, and its
weight is the downstream cost, which is not the cost of $q \to v$ (one leg of the lab measured 126 Mbit/s down and 424
up). Two bands between the same pair are parallel edges, merged into one by the MLO formula. The tree we want is an
arborescence rooted at the gateway. Not the minimum one (Chu-Liu/Edmonds), which minimises the sum of the edge
weights and can hang a box behind three cheap weak hops; the shortest-path one, which minimises every box's own path.
For readers from circuit theory: a hop's cost $1/T$ behaves like a resistance and the hops of a path are in series,
$C = \sum R_i$; the two legs of an MLO hop are *not* in parallel, because they share the time of one station.

No node has to give anything up for another: $C^\ast(v) \le C(v)$ for every $v$ and every tree. The plan is the
difference between the current tree and that one, and it is accepted only when it is worth what the moves cost:

```math
\Phi(\text{tree}^\ast) \le 0.8\ \Phi(\text{tree})
```

then carried out one measured move at a time, from the root down, so that every move already sees its parent on the
final path. The root becomes the box that holds the active internet uplink, not necessarily the controller.

What the model leaves out, honestly: a relay with several children splits its airtime among them, so the real cost of
a hop depends on the load on it, and the minimum under load is no longer a shortest-path tree. We will start from the
load-free tree, measure what is left, and only then decide whether the load needs to be in the model.

## Patches below EasyMesh

Every patch we apply to code we did not write is listed, one line each, in [PATCHES.md](PATCHES.md): 16 on the Wi-Fi
side (hostapd, wpa_supplicant, mac80211, mt76), 202 on the iopsys EasyMesh stack, and a few for the kernel, U-Boot and
LuCI. Most of the Wi-Fi ones fix corner cases of multi-link 4-address backhaul stations. Three of them (`0273`–`0275`)
correct TTLM frame handling in MediaTek's hostapd patches; they were reported to MediaTek and confirmed (September 2026),
and ours go away once MediaTek publishes its own fixes.

## Deviations from the EasyMesh specification

- Profile 3 capabilities are reported without DPP and without 1905 message security (both mandatory for certification,
  not for interoperability of the rest).

## Measurements

All on our five-box lab; the raw logs are not published yet.

| Date | What | Result |
|---|---|---|
| 2026-09-21 | Throughput by hop count (iperf3 to the controller) | 1 hop 418, 2 hops 89–152, 3 hops 29.7 Mbit/s - depth costs more than signal strength |
| 2026-09-23 | Negotiated TTLM per backhaul station, "all TIDs on 6 GHz" | 0 bytes on the 5 GHz link in both directions; setup and teardown 20/20 |
| 2026-09-25 | Band alternation across one repeater (downloads) | 153 → 260 Mbit/s |
| 2026-09-25 | Gateway failover, client outage | 24 → 11 s |
| 2026-10-01 | Gateway failover cable → LTE on another box (WAN port down for 120-180 s, Wi-Fi client pinging 1.1.1.1 every 0.2 s), rc3 | to LTE 10, 10, 11 s; back on the cable after ~30 s of stable cable, client gap 0, 32, 0 s. With the port up and only the traffic behind it dropped: no failover (the probe asks the first router, which still answered ARP) |
| 2026-09-28 | Parent planner, three measured trials in one night (a relay moved from 2 hops to 1) | about 120/250 → 1000/1080 Mbit/s up/down, all three kept |
