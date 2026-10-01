# EasyMesh Wi-Fi 7 for OpenWrt

**A Wi-Fi 7 mesh built from open-source routers, whose main box can steer which band each backhaul link carries.**

*Implements the Wi-Fi EasyMesh™ R6 specification; not certified by the Wi-Fi Alliance.*

> **Pre-release (v0.1-preview, <!-- TODO date -->).** It runs every day on a five-box lab, but it is not a product yet.
> We publish it early for reviewers and testers. Please read [Known limitations](#known-limitations) before you flash anything.
>
> **Everything here takes time - give it that time.** Pairing one box takes about 6-10 minutes including one restart
> (up to 15 on the Pro 8X), a box boots in about 2 minutes (5 on the Pro 8X), a move is measured for about 3 minutes. While
> a box joins, its lamp may go dark. **Do not press any button twice:** a second press cancels the pairing. Pairing a
> five-box mesh takes about three quarters of an hour - enough time for a beer or two. Just don't press any button twice
> while you wait.

![Overview: the mesh at a glance](docs/screenshots/overview.jpg)
<!-- TODO: retake all screenshots on the release images; ideally one short GIF where traffic moves to the other link -->

## What it does

- **One button to add a box.** Press *Pair a new box* on the main box (or its WPS button), then hold the WPS button on
  the new box. The new box joins the mesh, gets its settings and a name, and restarts once by itself while it joins.
- **Wi-Fi 7 multi-link backhaul.** Every box talks to its parent over two links at once (5 GHz and 6 GHz, MLO). The main
  box (the EasyMesh *controller*) can tell each backhaul link which band carries which traffic
  (*TID-to-Link Mapping*, TTLM) based on the shape of the whole mesh, not on one radio's view. In this preview the
  automatic policy runs as a dry run; the mechanism itself is verified on hardware.
- **Internet from any box.** Plug the internet cable into any box, or use an LTE modem in one of them as a backup. The
  mesh keeps one gateway address for all clients. When the cable is pulled, clients are back online in about 10-25
  seconds.
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

Any box can be the main box, and it can stand anywhere; a BPI-R4 Pro 8X can just as well be one of the others.

### 1. Prepare the cards
Download the image for your board from [Releases](https://github.com/woziwrt/openwrt-easymesh-wifi7/releases), check it
against `SHA256SUMS`, and write it to one SD card per box:

| Board | Image |
|---|---|
| BPI-R4, 4 GB | `openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz` |
| BPI-R4, 8 GB | `openwrt-mediatek-filogic-bananapi_bpi-r4-8gb-sdcard.img.gz` |
| BPI-R4 Pro 8X | `openwrt-mediatek-filogic-bananapi_bpi-r4-pro-8x-sdcard.img.gz` |

Set the boot switch of every box to SD. Like stock OpenWrt, every box starts at `http://192.168.1.1` with the user
`root` and **no password** (just click *Log in*).

The image starts with the Wi-Fi country set to **CZ** (Czech Republic). If you are elsewhere, set yours on each box in
*Network → WiFi Manager → Change Country* before you build the mesh. The backhaul uses 6 GHz where your country allows
it; we have built the mesh with CZ only.

### 2. The first box becomes the main box (controller)
Connect a computer to a LAN port of the first box - **not** the service port (**LAN3** on the BPI-R4, **LAN1** on the
Pro 8X) - and open `http://192.168.1.1`.
<!-- TODO (Petr 29. 9.): rewrite to "connect the computer to the service port from the start - the page then stays at
192.168.1.1 and nothing disappears" - only after it is verified on a fresh box -->
Go to *Network → EasyMesh → Setup* and click **This is my first box**. Enter the network name, the Wi-Fi password and a
name for the box. Leave *Mesh addresses* at `10.10.10.1` unless your home network already uses `10.10.10.x`; it must not
be `192.168.1.x`, which belongs to the service port. That is the only place where you type anything.
Click **Create the mesh**, then **Reboot now**. After about 2 minutes (5 on the Pro 8X) the main box answers at
**`http://10.10.10.1`** (or the address you chose), and the page moves there by itself. That LAN port is now part of the
mesh: your computer gets a `10.10.10.x` address from the main box.

**The internet cable** goes into the WAN port of **any** box, the main box or another one. The mesh has internet as soon
as that box has joined. The main box keeps one socket as a [service port](#the-service-port-a-way-in-when-the-mesh-is-not)
at `192.168.1.1`.

### 3. Add the other boxes, one at a time
**One box at a time, nearest first.** Pair a box only when the one before it is in the picture (*Overview* / *Nodes*).
Pressing the buttons of several boxes at once gives a bad result. Start with the box closest to the main box and work
outwards: a far box paired before the boxes between it and the main box gets its settings, but has nothing to attach its
5/6 GHz links to yet. That is not a fault - it keeps trying and joins by itself once the box in between is in the mesh.
For a place far from everything, pair the box next to the main box, switch it off, carry it there and switch it on.

Put the new box where it is meant to stand. For now it has to be within Wi-Fi reach of the **main box**: pairing is
opened there. Power the box on and wait until it has booted (about 2 minutes, 5 on the Pro 8X). Then:

1. **On the main box,** click *Pair a new box* in its *Overview*, or hold its WPS button for **4 to 8 seconds** (until the
   lamp blinks slowly) and let go. It keeps pairing open for about seven minutes, so there is time to walk over.
2. **On the new box,** hold the WPS button for **4 to 8 seconds** and let go.

A short press does not pair: the main box ignores it, and on a BPI-R4 that is not the main box it restarts it. The other order
(new box first) works too, but leaves only about three minutes.

The new box joins on its own in about four to six minutes, with nothing to type in, and restarts once by itself on the
way (that restart is expected, not a fault). It takes the Wi-Fi settings from the main box and appears in *Overview* and
*Nodes*. Then add the next one. Wait until it is there before you pair the next box, and do not press its button again
in the meantime: a second press cancels the pairing.

### 4. Check that it works
- *Overview* says **"Mesh is working"**, all boxes are online, every link is healthy.
- *Nodes* shows each box with its parent and both links (5 GHz and 6 GHz) **up**.
- **The picture is up to about a minute and a half behind the real state.** Each box averages its links over 30 s
  so that one bad second does not paint a healthy link red, and asking every box more often would spend the backhaul
  the mesh needs for your traffic. After a change, wait two minutes before judging it. The key in the corner of the
  picture says what the lines mean; hover a line for its numbers and their age.
- **A thick line with nothing of yours running is a measurement.** A trial move (yours, or the planner's when it is
  on) measures the throughput of a box before and after, about three minutes of traffic on that branch; *Events* says
  which box and why.
- If a box does not appear after fifteen minutes (or *Overview* says it has not finished), pair it again: *Pair a new
  box* on the main box, then hold the new box's button 4 to 8 seconds and let go. Not earlier - a second press cancels a
  pairing that is still running.
- **Set a root password on every box** (*System → Administration*) once it is in the mesh. The mesh does not need it;
  your network does. Until a box is set up, its Wi-Fi `OpenWrt-MLD` uses the published key `12345678` - so set the box
  up, or keep it off, while strangers are in range.
- To start a box over, hold its button **10 seconds**: that erases its settings (writing its SD card again does the
  same). There is one main box per mesh; if you made a second one by mistake (its *Overview* shows a mesh of one box),
  start that one over and pair it.

### The service port: a way in when the mesh is not

Once a box is part of a mesh, its LAN sockets belong to the mesh. **One socket is kept out of it for good** and answers
at **`192.168.1.1`** on every box, whatever the mesh is doing, across upgrades:

| Board | Service port |
|---|---|
| BPI-R4 (4 GB, 8 GB) | **LAN3** |
| BPI-R4 Pro 8X | **LAN1** (`mxl_lan0`) |

- **The box gives your computer an address there** (no gateway, no DNS, so your computer keeps its internet from
  elsewhere). A fixed address such as `192.168.1.2`, mask `255.255.255.0`, no gateway, works too.
- It is a way in, not a way out: no internet and no mesh traffic go through it.
- **Every box has the same address there.** Connect the service port of one box at a time, straight to your computer,
  never to a switch or to another box. Tell the boxes apart by the name in the web interface, not by the address.
- Use it when a box cannot be reached over the mesh (wrong settings, a box that lost its parent, a failed upgrade).
  In normal use you reach every box through the mesh.

### Upgrading

Flash the new `…squashfs-sysupgrade.itb` on each box with *System → Backup / Flash Firmware* and **keep the settings**.
The mesh settings, the box's role and the main box's database stay. Upgrade the boxes furthest from the main box first and
the main box last, one at a time, and wait until each is back in *Nodes* before the next (about 2 minutes, 5 on a Pro 8X).

## In this pre-release

✅ = verified on hardware in our lab · 🧪 = works, still running as a dry run or under test

- ✅ **Controller and agents based on the EasyMesh R6 specification** (the iopsys stack plus our patches; not certified)
  on OpenWrt 25.12 with the open mt76 driver, on BPI-R4 and BPI-R4 Pro 8X
- ✅ **Multi-link (MLO) backhaul** on 5 + 6 GHz between every box and its parent, relayed over several hops
- ✅ **One-button join** (WPS) with one restart of the new box on the way. A whole mesh can be built from blank SD cards.
- ✅ **Per-station TTLM driven by the controller:** the controller maps traffic of one backhaul link to one band, in
  both directions, and removes the mapping again
- 🧪 **Automatic TTLM policy:** avoiding a bad link, and alternating bands across a repeater (+70 % across one repeater, 2 hops,
  downloads, in one test series). Runs as a dry run by default.
- ✅ **Persistent controller database:** topology, links, clients and history survive restarts
- 🧪 **Gateway failover** between cable and LTE on any box, one gateway address for clients, an outage of about 10-25 s
- ✅ **Self-healing after power loss:** repeated power cycles of the whole mesh, and it came back on its own every time
- 🧪 **Choosing the parent:** the controller moves a box to a better parent on its own, by two plain rules. **Rescue,
  on by default:** its path is bad (under ~100 Mbit/s) and another parent is at least twice as good. **Towards the main
  box, off by default (danger zone):** another parent one hop closer to the controller is at least 1.5 times as good.
  Every move is a measured trial on the box itself (throughput before and after, three rounds each) and is kept only if
  it paid; otherwise the box goes back on its own. One trial in the mesh at a time. In a test after a controller
  restart, three moves brought a relay from 26/47 to 1044/1143 Mbit/s (up/down). In another, a relay was moved by hand
  and two of its children landed on parents at 3 and 6 Mbit/s; the rescue moved them on its own within eight minutes,
  to 190/208 and 207/376 Mbit/s - see [What the mesh does by itself](#what-the-mesh-does-by-itself).
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
- **Arranging the tree from measured links:** the first parent after a start chosen from scans, one measuring method for
  all decisions, a trial move without test traffic, and *Try it → Possible → Confirm* for a move by hand
- **Packages instead of images:** install on an existing OpenWrt 25.12 box, with a setup wizard
- **Upstream:** send our driver and hostapd fixes to their maintainers, patch by patch

## What the mesh does by itself

What matters most is that your devices stay online, so nothing moves a box for speed alone unless you switch it on.
The one exception is a box left on a path under about 100 Mbit/s - that is moved, with a measured trial:

| Mechanism | By default | What it does | What it costs |
|---|---|---|---|
| Finding a new parent after a box or its parent restarts | on | the backhaul joins the best parent it hears, within seconds | the boxes behind a restarting box are offline for 30-60 s; after a restart of the main box the whole mesh re-forms, which takes a few minutes |
| No island ([details](docs/TECHNICAL.md#self-healing-and-optimisation)) | on | a box without a path to the main box stops accepting others at once | nothing |
| Bridges follow a moved box | on | every box forgets its learned bridge entries when the tree changes | nothing noticeable |
| Moving a box by hand | when you ask | *Backhaul & MLO* → *Move…* next to a box: pick a parent it hears; a measured trial keeps the move only if it is faster, otherwise the box goes back by itself | a few seconds for the box and the boxes behind it; one to three minutes if the new parent does not answer; about three minutes of test traffic |
| Rescue of a box on a bad path | **on** | a box on a path under ~100 Mbit/s moves to a parent at least twice as good, one measured trial at a time; back if it did not pay | as a move by hand, only while a box is that slow |
| Parent planner: towards the main box (danger zone) | **off** (logs only) | also moves a box to a parent one hop closer to the main box when that is clearly better | as a move by hand, whenever it decides to |
| Stuck-box rescue | **off** (logs only) | a box that loses most pings to the main box moves to a parent at least 10 dB stronger, and goes back if that does not work | a few seconds, or one to three minutes if the new place does not answer |
| Deaf-link guard | **off** (logs only) | a box whose parent's beacons are all gone reconnects | the box and the boxes behind it drop for a moment |
| TTLM rules (band steering of the backhaul) | **off** (logs only) | moves traffic of a backhaul link to its better band | nothing noticeable |

**Danger zone.** The switch on *Backhaul & MLO* (or `touch /etc/mapc/parent-steer-live` on the main box) turns on
optimisation algorithms that are still in development. They can arrange the mesh into an illogical topology - a box
under a parent further away than it needs, or a relay hanging below a box it should be serving. Switching them off
again does not restore the previous topology: the correct tree can then only be restored by moving boxes by hand with
*Move…*. What the planner decides, and what it would do while off, is in *Backhaul & MLO* and *Events*. The rescue and
the deaf-link guard are switched on the boxes with
`touch /etc/mapc/bh-rescue-live` and `touch /etc/mapc/deaf-guard-live`.

**How long things take** (measured in our lab):
- a new box joins and carries traffic about four to six minutes after you pair it, including its one restart (longer
  on the Pro 8X);
- after a power cut of the whole mesh, clients are back on the internet in about 1.5 minutes and every box is back in
  under 3 minutes;
- when one box restarts, the clients and boxes behind it are back within about a minute; after a restart of the main box
  alone, it takes a few minutes, and the rescue may then need 10-20 minutes to rebuild the chains (see *Known limitations*);
- a move by hand is decided in about three to four minutes;
- with the planner on, it waits until a box has been stable for about 7 minutes before it tries a move.

## Known limitations

This is a preview. What is not done yet, or not done well:

- **Band steering of the backhaul is a dry run by default.** The TTLM rules decide and log what they would do; they only
  act when switched on (`/etc/mapc/ttlm-policy-live`, `/etc/mapc/ttlm-alternate-live`). Per-station TTLM from the
  controller works on hardware in both directions. The automatic *policy* on top of it still needs more nights of testing.
- **The parent planner is deliberately simple.** It corrects parents that are plainly wrong and leaves near-ties
  alone. It estimates a box's own first hop from signal, which can be far off for a noisy card, and it plans toward
  the controller, not toward whichever box currently holds the internet uplink (see *Planned*).
- **BE14 cards differ, so measure yours.** Some are noisier than others (7–13 dB on the same channel in our lab), and
  on one of our cards the 6 GHz link runs on a single stream at a low rate where the others run on two. On such a card,
  the box's own 5 GHz beacon can briefly deafen its 6 GHz receiver. The mesh detects noisy cards and shows them in
  *Nodes*; `easymesh-card-check` on a box measures its card. A mitigation is being tested. Such a box does best at the
  end of a chain. These are measurements of the few cards we have, not a statement about the cards in general.
- **Check the antenna connectors.** A loose or torn antenna connector shows as one chain far below the other two in
  `iw dev bsta-mld-3 station dump` (e.g. `signal: -68 [-86, -69, -73] dBm` on the 6 GHz link). In our lab two boxes had
  that on 6 GHz, and as parents they accepted 6 GHz authentication only 3 and 0 times out of 6 - their children then
  join over 5 GHz only. `easymesh-card-check` does not look at chains yet.
- **EasyMesh Profile 3 without message security.** DPP onboarding and 1905 encryption are not implemented. Onboarding is
  WPS push-button. The backhaul links themselves are encrypted Wi-Fi (WPA3-SAE). We report Profile 3 capabilities (needed
  for Wi-Fi 7 link reports), so a third-party controller that enforces Profile 3 security will reject our agents: in this
  preview the mesh is meant to be built from our boxes only.
- **5 GHz stays on channel 36** (no radar channels) by default: the cards cannot watch for radar in the background.
- **Every move costs a moment of connectivity.** When a box is moved - by hand or by the planner - that box and the
  boxes behind it are off the mesh for a few seconds, for one to three minutes if the new parent does not answer, and a
  trial loads that branch with test traffic for about three minutes while it measures. That is why, by default, only a
  box on a path under about 100 Mbit/s is moved (`touch /etc/mapc/parent-rescue-off` on the main box stops even that).
- **After pairing, a power cut or a restart of the main box, the tree follows the radio, not the floor plan.** The tree
  is whoever answers first: a box may hang behind a box with a weaker card, or one hop further from the main box than it
  needs to be. **It can look illogical - we know, and arranging the tree from measured links comes in a later release**
  (see *Planned*). The mesh works, some paths are slower; a box left under about 100 Mbit/s is rescued by itself. Until
  then, put a box where you want it with *Move…*.
- **After a restart of the main box alone, the mesh tends to become a star.** Relays drop their children while their own
  path is down, so when the main box comes back every box attaches straight to it, far ones at a few Mbit/s. The rescue
  then rebuilds the chains one box at a time - 10-20 minutes in our tests. Keeping children attached while a relay
  reconnects is planned. (A power cut of the whole mesh does not do this: the boxes start together.)
- **Not fully understood, with a defence in place:** after pairing from a blank card, a box sometimes cannot authenticate
  over 6 GHz and joins over 5 GHz only; its traffic to the parent can then stall. In our lab this happened towards parents
  with a damaged 6 GHz antenna connector (see *Check the antenna connectors*). The box restarts once by itself during
  pairing, which clears it in our tests, and a guard restarts a box whose uplink stalls twice within half an hour.
- **A box that lost its parent can pick a weak 6 GHz link.** It reconnects to what it hears, and wpa_supplicant may
  prefer a 6 GHz link at -80 dBm to a better 5 GHz one (once in our lab: 0/4 Mbit/s for 15 minutes). If its path stays
  under about 100 Mbit/s, the rescue moves it; a faster choice of the band is planned.
- **On the BPI-R4 Pro 8X the lamps do not show pairing.** Its board wires the LEDs differently, so holding its WPS
  button gives no blink. The press still works - just wait. A Pro 8X can also restart twice while it joins instead of
  once (it boots slowly, about five minutes), so give it 10-15 minutes.
- **Sometimes the Wi-Fi card does not start.** Now and then the MT7996 firmware fails to load at boot
  (`Failed to start patch` / `probe failed -11` in the kernel log) and the box runs without Wi-Fi. A restart does not
  help: **switch the power off for 30 seconds.** The Pro 8X cannot reset its Wi-Fi card from software. You notice it
  because the box does not come back into *Nodes*.
- **A box that lost one of its two backhaul links keeps going on one.** The mesh does not reconnect it to get the
  second link back on purpose: a reconnection takes the box and every box behind it off the mesh for up to a minute.
- **The controller database lives on the boot medium.** A slow SD card can stall the main box for seconds; use a good
  one (A1 or better). This release runs from the SD card only; installing to eMMC, NAND or NVMe is not part of it.
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
according to the mesh topology, on an open-source stack** (open mt76 driver, hostapd and EasyMesh stack; the Wi-Fi
firmware is MediaTek's binary). The TTLM actuator in the driver is MediaTek's; the decision and
its delivery over EasyMesh (IEEE 1905, *Service Prioritization Request*) are ours. We do **not** claim to have invented TTLM
or controller-driven link mapping. The idea is in the EasyMesh specification, and closed implementations may exist.
How to check the claim yourself: [docs/TECHNICAL.md → Verifying](docs/TECHNICAL.md#verifying-the-claim).

## For reviewers

Written for three groups: **BPI-R4 users on OpenWrt** (images, the install steps, what works and what does not),
**Banana Pi / Sinovoip** (Wi-Fi 7 mesh on their boards on an open stack, and how cards and boards measured in our lab),
and **Wi-Fi driver, hostapd and EasyMesh developers** (patches, messages, measurements).

- **Wi-Fi driver, hostapd and EasyMesh people:** the architecture, the messages we use, where we deviate from the
  specification and the measurements are in [docs/TECHNICAL.md](docs/TECHNICAL.md); every patch below the EasyMesh layer
  is listed in [docs/PATCHES.md](docs/PATCHES.md). Review of single patches is very welcome.
- **Testers:** a report with two boxes is already useful. Please attach the output of `easymesh-check` and a screenshot of
  *Nodes*. Issues are welcome; this is one person's project and they are answered when time allows - there is no support.


## Building from source

The exact recipe (OpenWrt, MediaTek feed and iopsys feed pinned to commits) is in [BUILD.md](BUILD.md): one script per
board, `./build-bpi-r4.sh` and `./build-bpi-r4-pro-8x.sh`.

## Who made it

Petr Wozniak, in collaboration with Claude, an AI assistant by Anthropic. Every change was built, flashed and tested on
real hardware - a five-box lab running around the clock. The numbers in this README come from that lab and from dated
tests; [docs/TECHNICAL.md](docs/TECHNICAL.md) has the details.

## License

Our code: BSD-3-Clause (EasyMesh services, LuCI app), GPL-2.0-or-later (kernel and device tree changes). Patches keep the
license of the code they change. Third-party components keep their own licenses (iopsys: BSD-3-Clause, hostapd: BSD,
mt76: ISC). See [LICENSE](LICENSE) and [LICENSES.md](LICENSES.md).

Copyright (c) 2026, Petr Wozniak (WOZIWRT project)

This project implements the EasyMesh R6 specification but is not certified by the Wi-Fi Alliance. Wi-Fi EasyMesh is a
trademark of the Wi-Fi Alliance.
