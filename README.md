# EasyMesh Wi-Fi 7 for OpenWrt

**A Wi-Fi 7 mesh built from open-source routers that decides by itself which way the traffic flows.**

> **Pre-release (v0.1-preview, <!-- TODO date -->).** It runs every day on a five-box lab, but it is not a product yet.
> We publish it early for reviewers and testers. Please read [Known limitations](#known-limitations) before you flash anything.

![Overview: the mesh at a glance](docs/screenshots/overview.jpg)
<!-- TODO: retake all screenshots on the release images; ideally one short GIF where traffic moves to the other link -->

## What it does

- **One button to add a box.** Press the WPS button on the new box, then on the main box (or *Pair a new box* in the web interface). The new box joins
  the mesh, gets its settings and a name, and does not need to reboot.
- **Wi-Fi 7 multi-link backhaul.** Every box talks to its parent over two links at once (5 GHz and 6 GHz, MLO). The main
  box (the EasyMesh *controller*) can tell each backhaul link which band carries which traffic
  (*TID-to-Link Mapping*, TTLM) based on the shape of the whole mesh, not on one radio's view.
- **Internet from any box.** Plug the internet cable into any box, or use an LTE modem in one of them as a backup. The
  mesh keeps one gateway address for all clients. When the cable is pulled, clients are back online in about 11 seconds.
- **It tells you what is going on.** The web interface (LuCI) shows every box, every link and every client in plain words.
  It also points out a radio card that is noisier than the others, so a slow link is not blamed on the mesh.

## Screenshots

| | |
|---|---|
| ![Nodes](docs/screenshots/nodes.jpg) **Nodes:** where each box sits, its links, its radio card | ![Clients](docs/screenshots/clients.jpg) **Clients:** per box, multi-link or single link, signal history, link rate |
| ![Backhaul](docs/screenshots/backhaul.jpg) **Backhaul & MLO:** both links of every hop and what the controller does with them | ![Channels](docs/screenshots/channels.jpg) **Channels:** noise and load as each box hears it |
| ![Events](docs/screenshots/events.jpg) **Events:** the last 24 hours in plain words | ![Setup](docs/screenshots/setup.jpg) **Setup:** start a new mesh or join one, and how to add a box <!-- TODO: shoot the wizard on an unconfigured box --> |
| ![Advanced](docs/screenshots/advanced.jpg) **Advanced (support):** steering history, the controller database and the raw API, for troubleshooting | |

## Getting started

**You need:**
- **2 boxes** to see the core of it (a controller and one agent over a multi-link backhaul, TTLM on that link);
- **3 or more** to see a real mesh (chains, choice of parent, relaying);
- Banana Pi **BPI-R4** (4 GB or 8 GB) or **BPI-R4 Pro 8X**, each with the **BPI-R4-NIC-BE14** Wi-Fi 7 card (MT7996);
- a microSD card per box. Running from SD leaves whatever is in the box's own flash untouched: take the card out and the
  box boots its old system.

### 1. Prepare the cards
Download the image for your board from [Releases](<!-- TODO -->) and write it to one SD card per box
(`bananapi_bpi-r4-*-sdcard.img.gz` <!-- TODO exact file names -->). Set the boot switch of every box to SD.

### 2. The first box becomes the main box (controller)
Connect a computer to a LAN port of the first box (**not LAN3**, on the Pro 8X **not LAN1** - that one becomes the
service port), plug the internet cable into its WAN port, and open `http://192.168.1.1`.
Go to *Network → EasyMesh → Setup* and choose *Start a new mesh*. Enter the Wi-Fi name, the Wi-Fi password and a name for
the box. That is the only place where you type anything.
After setup that LAN port is part of the mesh: your computer stays connected and gets its address from the main box.
The main box keeps one socket as a [service port](#the-service-port-a-way-in-when-the-mesh-is-not) at `192.168.1.1`.

### 3. Add the other boxes, one at a time
Put the new box where it is meant to stand. For now it has to be within Wi-Fi reach of the **main box**: pairing is
opened there. Power the box on and wait until it has booted (about 2 minutes, 5 on the Pro 8X).

- **With buttons only (no computer):**
  1. Hold the **WPS button on the new box** for three seconds and let go.
  2. Within two minutes press the **WPS button on the main box**. <!-- TODO verify the window tonight (clean re-pairing 25 Sep) -->
- **From the web interface:** do step 1 on the new box, then click *Pair a new box* in the main box's *Overview* instead of
  pressing its button.

The new box joins on its own in about four minutes, without a reboot and with nothing to type in. It takes the Wi-Fi
settings from the main box and appears in *Overview* and *Nodes*. Then add the next one.
<!-- TODO: photo of the WPS button on the R4 and the Pro 8X; what the LEDs show while pairing -->

### 4. Check that it works
- *Overview* says **"Mesh is working"**, all boxes are online, every link is healthy.
- *Nodes* shows each box with its parent and both links (5 GHz and 6 GHz) **up**.
- **The picture is up to about a minute and a half behind the real state.** Each box averages its links over 30 s
  so that one bad second does not paint a healthy link red, and asking every box more often would spend the backhaul
  the mesh needs for your traffic. After a change, wait two minutes before judging it. The key in the corner of the
  picture says what the lines mean; hover a line for its numbers and their age.
- If a box does not appear after five minutes: press both buttons again. If that does not help, see
  [Troubleshooting](docs/TROUBLESHOOTING.md) <!-- TODO -->.

### The service port: a way in when the mesh is not

Once a box is part of a mesh, its LAN sockets belong to the mesh. **One socket is kept out of it for good** and answers
at **`192.168.1.1`** on every box, whatever the mesh is doing, across upgrades:

| Board | Service port |
|---|---|
| BPI-R4 (4 GB, 8 GB) | **LAN3** |
| BPI-R4 Pro 8X | **LAN1** (`mxl_lan0`) |

- **No DHCP on it.** Give your computer a fixed address, e.g. `192.168.1.2`, mask `255.255.255.0`, no gateway.
- It is a way in, not a way out: no internet and no mesh traffic go through it.
- **Every box has the same address there.** Connect the service port of one box at a time, straight to your computer,
  never to a switch or to another box. Tell the boxes apart by the name in the web interface, not by the address.
- Use it when a box cannot be reached over the mesh (wrong settings, a box that lost its parent, a failed upgrade).
  In normal use you reach every box through the mesh.

## In this pre-release

✅ = verified on hardware in our lab · 🧪 = works, still running as a dry run or under test

- ✅ **EasyMesh R6 controller and agents** on OpenWrt 25.12 with the open mt76 driver, on BPI-R4 and BPI-R4 Pro 8X
- ✅ **Multi-link (MLO) backhaul** on 5 + 6 GHz between every box and its parent, relayed over several hops
- ✅ **One-button join** (WPS) without a reboot, with one guarded reboot as a fallback. A whole mesh can be built from
  blank SD cards.
- ✅ **Per-station TTLM driven by the controller:** the controller maps traffic of one backhaul link to one band, in
  both directions, and removes the mapping again
- 🧪 **Automatic TTLM policy:** avoiding a bad link, and alternating bands across a repeater (+70 % across one repeater, 2 hops,
  downloads, in one test series). Runs as a dry run by default.
- ✅ **Persistent controller database:** topology, links, clients and history survive restarts
- ✅ **Gateway failover** between cable and LTE on any box, one gateway address for clients, ~11 s outage
- ✅ **Self-healing after power loss:** repeated power cycles of the whole mesh, and it came back on its own every time
- 🧪 **Choosing the parent:** the controller moves a box to a better parent on its own, by two plain rules - its path is
  bad (under ~100 Mbit/s) and another parent is at least twice as good, or another parent one hop closer to the
  controller is at least 1.5 times as good. Every move is a measured trial on the box itself (throughput before and
  after, three rounds each) and is kept only if it paid; otherwise the box goes back on its own. One trial in the mesh
  at a time. In a test after a controller restart, three moves brought a relay from 26/47 to 1044/1143 Mbit/s
  (up/down). Running every night under test.
- ✅ **No island when a relay reboots:** a box that has lost its path to the controller stops accepting other boxes on
  its backhaul at once and drops the ones it had, so two children of a rebooting relay cannot join each other
- ✅ **Wi-Fi for clients stays up while a backhaul moves:** a backhaul that lost its parent keeps the box's access
  points running for 20 s, enough to find a new parent on the same channel (a move took ~6 s instead of ~26 s off air)
- ✅ **Bridges follow a moved box:** when the backhaul tree changes, every box forgets its learned bridge entries at
  once. Without it, a box that moved behind another relay was unreachable for up to five minutes.
- 🧪 **A box stuck on a parent it cannot use moves by itself:** when most pings to the main box are lost and a much
  stronger parent is in range, the box moves there, and goes back if the new place does not work. It needs no help from
  the main box, which cannot reach it in that state anyway.
- ✅ **Backhaul watchdogs:** a backhaul BSS that stopped beaconing is re-armed. A backhaul station that has moved away is
  dropped by its old parent.
- ✅ **Radio card check:** noisy cards are found and named in the UI
- ✅ **LuCI app with 8 tabs:** Overview, Nodes, Clients, Backhaul & MLO, Channels, Events, Setup, Advanced
- ✅ **JSON API over ubus** for everything the UI shows

## Planned for the next releases

- **Moving a box by hand in LuCI:** pick a parent, and the same measured trial decides - a move that does not pay is
  undone by itself
- **Topology planned toward the gateway, from measured links:** the controller remembers the measured throughput of
  every backhaul link it has seen, per direction, in its database, together with the 5 GHz and 6 GHz signal at the time.
  A record whose signal no longer matches on either band is dropped, so a box that has been moved loses only its own
  links. From these links the controller computes the tree with the least airtime from the *active gateway* to every box
  (downstream, where client traffic goes), rather than toward the controller, and moves boxes one at a time, with
  hysteresis. If the WAN cable is moved to another box, the mesh rearranges around it. A temporary failover to LTE does
  not rearrange anything. This is the airtime metric known from 802.11s and mesh routing protocols. What we add is
  applying it to EasyMesh topology from the controller.
- **Traffic statistics history:** traffic per box, backhaul link and client, link quality, topology changes, outages and
  gateway failovers over hours, days and weeks, kept in the controller database with retention, shown as graphs in LuCI
  and exported through the API
- **TTLM policy switched on by default,** after enough A/B measurements, with per-direction STR checks and noisy cards
  kept out of relaying
- **Mitigation for noisy BE14 cards** (beacon timing), on by default once confirmed
- **Join from any box:** press the button on the nearest box of the mesh, not only on the main one (EasyMesh push-button event propagation)
- **Interoperability** with other vendors' EasyMesh controllers and agents, in both roles
- **Conformance with the specification:** follow the EasyMesh R6 specification closely and check the mesh against the
  publicly listed EasyMesh test cases, so that a vendor who builds on it could take it to certification
- **Radar channels (DFS)** as an option, and channel suggestions from scans
- **Onboarding with DPP (Easy Connect)**
- **Capacity in the UI:** measured maximum of each link, not only the current traffic
- **Packages instead of images:** install on an existing OpenWrt 25.12 box, with a setup wizard
- **Upstream:** send our driver and hostapd fixes to their maintainers, patch by patch

## Known limitations

This is a preview. What is not done yet, or not done well:

- **Band steering of the backhaul is a dry run by default.** The TTLM rules decide and log what they would do; they only
  act when switched on (`/etc/mapc/ttlm-policy-live`, `/etc/mapc/ttlm-alternate-live`). Per-station TTLM from the
  controller works on hardware in both directions. The automatic *policy* on top of it still needs more nights of testing.
- **The parent planner is deliberately simple.** It corrects parents that are plainly wrong and leaves near-ties
  alone. It estimates a box's own first hop from signal, which can be far off for a noisy card, and it plans toward
  the controller, not toward whichever box currently holds the internet uplink (see *Planned*).
- **Some BE14 cards are noisier than others** (7–13 dB on the same channel in our lab). On such a card, the box's own
  5 GHz beacon can briefly deafen its 6 GHz receiver. The mesh detects these cards and shows them in *Nodes*. A mitigation
  is being tested. Such a box does best at the end of a chain.
- **EasyMesh Profile 3 without message security.** DPP onboarding and 1905 encryption are not implemented. Onboarding is
  WPS push-button. The backhaul links themselves are encrypted Wi-Fi (WPA3). <!-- TODO verify SAE on release image -->
- **5 GHz stays on channel 36** (no radar channels) by default: the cards cannot watch for radar in the background.
- **The controller database lives on the boot medium.** On a slow SD card, a large database write can stall the box for
  seconds. For daily use put the controller on NVMe or eMMC.
- The web interface is in English only.

## What is ours and what is not

Built on the work of others, and we say exactly where the line runs:

| Layer | From |
|---|---|
| OpenWrt 25.12, Linux 6.12 | OpenWrt project |
| Wi-Fi driver (mt76), hostapd, wpa_supplicant, firmware; **the TTLM mechanism itself** (mt76 patch `0073`, Michael-CY Lee) | MediaTek (via the MediaTek OpenWrt feed) |
| EasyMesh stack: `ieee1905`, `map-controller`, `map-agent`, `wifimngr`, `libwifi` | iopsys / Genexis (BSD-3-Clause) |
| Patches on top of that stack (multi-link backhaul, TTLM policy transport, reporting fixes, …) | **ours** |
| Mesh services: setup and one-button join, persistent controller database, gateway failover, link watchdogs, radio card check, TTLM policy producer, LuCI app | **ours** |

**Our claim, stated precisely:** as far as we could find (search of public code and papers, September 2026), this is the
first **publicly documented, hardware-measured** EasyMesh controller that **drives TID-to-Link Mapping of backhaul links
according to the mesh topology, on a fully open stack.** The TTLM actuator in the driver is MediaTek's; the decision and
its delivery over EasyMesh (IEEE 1905, *Service Prioritization Request*) are ours. We do **not** claim to have invented TTLM
or controller-driven link mapping. The idea is in the EasyMesh specification, and closed implementations may exist.
How to check the claim yourself: [docs/TECHNICAL.md → Verifying](docs/TECHNICAL.md#verifying-the-claim).

## For reviewers

- **Wi-Fi driver / hostapd people:** our changes below the EasyMesh layer are small and listed patch by patch in
  [docs/TECHNICAL.md → Patches](docs/TECHNICAL.md#patches-below-easymesh). Most of them fix corner cases we hit with
  multi-link 4-address backhaul stations. Review of single patches is very welcome.
- **EasyMesh people:** the architecture, the messages we use and where we deviate from the specification are in
  [docs/TECHNICAL.md](docs/TECHNICAL.md).
- **Testers:** a report with two boxes is already useful. Please attach the output of `easymesh-check` and a screenshot of
  *Nodes*. <!-- TODO: issue template -->

## Building from source

The exact recipe (OpenWrt, MediaTek feed and iopsys feed pinned to commits) is in [BUILD.md](BUILD.md): one script per
board, `./build-bpi-r4.sh` and `./build-bpi-r4-pro-8x.sh`.

## Who made it

Petr Wozniak, in collaboration with Claude, an AI assistant by Anthropic. Every change was built, flashed and tested on
real hardware - a five-box lab running around the clock.

## License

Our code: BSD-3-Clause (EasyMesh services, LuCI app), GPL-2.0-or-later (kernel and device tree changes). Patches keep the
license of the code they change. Third-party components keep their own licenses (iopsys: BSD-3-Clause, hostapd: BSD,
mt76: ISC). See [LICENSE](LICENSE) and [LICENSES.md](LICENSES.md).

Copyright (c) 2026, Petr Wozniak (WOZIWRT project)

This project implements the EasyMesh R6 specification but is not certified by the Wi-Fi Alliance. Wi-Fi EasyMesh is a
trademark of the Wi-Fi Alliance.
