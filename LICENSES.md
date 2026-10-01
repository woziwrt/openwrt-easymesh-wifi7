# Licenses and origins

| Part | License | Author / origin |
|---|---|---|
| `feed/` EasyMesh packages, `luci-app-easymesh` | BSD-3-Clause | Petr Wozniak (WOZIWRT project) |
| `feed/luci-app-wifimgr` | GPL-2.0-or-later | Petr Wozniak |
| `build-*.sh`, `scripts/`, `pins.conf`, `configs/`, our board scripts | BSD-3-Clause | Petr Wozniak (WOZIWRT project) |
| `iopsys/overlay/` patch series | as the package they patch (iopsys: BSD-3-Clause) | Petr Wozniak; each patch names its author |
| `iopsys/overlay/*/Makefile`, init and uci-defaults scripts | as upstream | IOPSYS Software Solutions AB / Genexis, with our changes |
| `patches/wifi/` | as the component they patch (hostapd: BSD-3-Clause, mt76: ISC, mac80211: GPL-2.0) | each patch names its author |
| `patches/luci/` | as LuCI (Apache-2.0) | Petr Wozniak |
| `patches/kernel/`, `patches/mtk-feed/`, `patches/uboot/`, `boards/*/patches-*` | GPL-2.0 (kernel, U-Boot) | each patch names its author |
| `extras/` - LuCI apps by other authors (CPU/temperature status, scheduled reboot, connection watchdog, modem status, SMS) | each package's own license (see its LICENSE / Makefile) | their authors; included as published |
| `extras/modemdata-addons/usb/1bc71071` - Telit FN990 support for modemdata | as modemdata | written for this project; added to modemdata at build time |

Not in this repository, fetched by the build: `modemdata` (Cezary Jackiewicz, github.com/obsy/modemdata, pinned in `pins.conf`) -
upstream publishes it without a license, so we do not redistribute it. `sms-tool` comes from the OpenWrt packages feed.

## In the images, not in this repository

The build fetches and the images carry, each under its own license: OpenWrt and its package feeds (mostly GPL-2.0 and
others per package), LuCI (Apache-2.0), the MediaTek OpenWrt feed (mt76: ISC; hostapd: BSD-3-Clause), the iopsys stack
(BSD-3-Clause) and the **MediaTek Wi-Fi and Ethernet firmware, which is a proprietary binary** redistributed under
MediaTek's firmware license, not open source.

## Modified copies of upstream files

These files replace an upstream file during the build. They carry no header of
our own; the upstream copyright inside them applies.

| File | Derived from | Our change |
|---|---|---|
| `boards/common/arm-trusted-firmware-mediatek-Makefile` | OpenWrt `package/boot/arm-trusted-firmware-mediatek/Makefile` (openwrt-25.12 `413b237d13`) | `mt7988-*-comb-4bg` targets, backported from OpenWrt `6141cd1dbc` (Frank Wunderlich) |
| `boards/bpi-r4-pro-8x/uboot-mediatek-Makefile` | OpenWrt `package/boot/uboot-mediatek/Makefile` (openwrt-25.12 `413b237d13`) | BPI-R4 Pro 8X targets (after OpenWrt `3aa068ac71`, Andrew LaMarche / Frank Wunderlich), serial RX buffer for tools |
| `boards/*/filogic.mk` | OpenWrt `target/linux/mediatek/image/filogic.mk` as modified by the MediaTek feed | BPI-R4 devices only; NVMe GPT, eMMC/NVMe/SNAND image artifacts, `comb-4bg`, overlays; own BPI-R4 Pro 8X device |
| `boards/*/fit.sh` | OpenWrt `package/utils/fitblk/files/fit.sh` (Daniel Golle) | NVMe sysupgrade path; on the Pro 8X the image name follows the board model |

## Patches based on other people's work

| Patch | Original author | Note |
|---|---|---|
| `patches/wifi/0118-…` | Peter Chiu (MediaTek) | unmodified backport of mtk-openwrt-feeds `73e7f7db` |
| `patches/uboot/450-add-bpi-r4.patch` | Daniel Golle | OpenWrt patch at `011ba05f`, one line changed |
| `boards/bpi-r4-pro-8x/patches-uboot/471-…` | Andrew LaMarche, Frank Wunderlich | OpenWrt `472-add-bpi-r4-pro-8x.patch`, extended |
| `boards/bpi-r4-pro-8x/patches-kernel/046-…` | Sam Shih (MediaTek), via BPI-SINOVOIP | BPI-R4 Pro device tree adapted to the Pro 8X |
| `boards/bpi-r4-pro-8x/patches-kernel/047-…` | Frank Wunderlich, Daniel Golle | overlays adapted to the Pro 8X |
| `boards/bpi-r4-pro-8x/patches-kernel/999-eth-00/01/02-…` | Bo-Cun Chen (MediaTek) | ported from Linux 6.6 to 6.12 |
| `patches/mtk-feed/kernel/999-sfp-10-additional-quirks.patch` | unknown (community SFP module quirks) | included unchanged, without an author line |
