# Technical overview

For people who know Wi-Fi 7 MLO or EasyMesh and want to know what exactly happens. The user-facing README is one level
up.

<!-- TODO before release: every number below links to a measurement log in docs/measurements/ -->

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
   <!-- TODO: exact TLV layout; our patch numbers in map-controller (9995) and map-agent (9993) -->
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

<!-- TODO: script verify-ttlm.sh that does 1–3 on two boxes and prints PASS/FAIL -->

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

## Patches below EasyMesh

<!-- TODO: generate this table from the patch headers (From:, Subject:), one line each, grouped:
     hostapd/wpa_supplicant · mac80211 · mt76 · iopsys stack (ieee1905, map-agent, map-controller, wifimngr, libwifi).
     Note for hostapd: three fixes (0273–0275) correct TTLM frame handling in MediaTek's patches. They were reported
     to MediaTek and confirmed (Sep 2026); MediaTek has equivalent fixes internally, and ours go away once those are published. -->

## Deviations from the EasyMesh specification

- Profile 3 capabilities are reported without DPP and without 1905 message security (both mandatory for certification,
  not for interoperability of the rest).
- <!-- TODO: list from our patch descriptions (e.g. reporting under the MLD address) -->

## Measurements

<!-- TODO: link logs. Candidates with dates:
     2026-09-21 hop cost: 1 hop 418, 2 hops 89–152, 3 hops 29.7 Mbit/s (depth outweighs RSSI)
     2026-09-23 per-station Neg-TTLM, 20/20, 0 B on the unmapped link both ways
     2026-09-25 band alternation across a repeater 153 → 260 Mbit/s
     2026-09-25 gateway failover 24 → 11 s client outage -->
