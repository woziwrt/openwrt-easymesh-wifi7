# OpenWrt EasyMesh for Wi-Fi 7

A Wi-Fi 7 mesh built from open routers, which decides by itself where the
traffic flows.

> **Status: work in progress.** This repository is being prepared for its
> first public preview. Build instructions are in [BUILD.md](BUILD.md).

## What it is

- An [EasyMesh](https://www.wi-fi.org/discover-wi-fi/wi-fi-easymesh) controller
  and agent running on OpenWrt, on Banana Pi BPI-R4 and BPI-R4 Pro 8X routers
  (MediaTek MT7988A + MT7996 Wi-Fi 7).
- Nodes are linked by a Wi-Fi 7 multi-link (MLO) backhaul; the controller steers
  traffic between the links of each connection using TID-to-Link Mapping, based
  on the topology of the mesh.
- Built on the open stack end to end: OpenWrt, mt76, hostapd and the
  [iopsys](https://dev.iopsys.eu) Multi-AP stack, with our changes on top.

## What is ours and what is not

| Part | Origin |
|---|---|
| `feed/` - EasyMesh packages, LuCI pages | this project |
| `iopsys/overlay/` - changes to the Multi-AP stack | this project, on top of iopsys |
| `patches/wifi/` - hostapd, mt76, mac80211 fixes | this project, except where a patch names another author |
| TID-to-Link Mapping in the mt76 driver | MediaTek (their patch series in mtk-openwrt-feeds); we control it from the mesh controller |
| Board support patches | mixed; each patch names its author |

## License

Our code is licensed under the BSD 3-Clause License (see [LICENSE](LICENSE)),
except where a file states otherwise (LuCI Wi-Fi manager and kernel/U-Boot
patches: GPL-2.0-or-later). Upstream components keep their own licenses.
