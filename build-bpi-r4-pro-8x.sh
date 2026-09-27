#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# Production image for the Banana Pi BPI-R4 Pro 8X with the EasyMesh stack
# baked in. Everything about Wi-Fi and the mesh is in scripts/common.sh; this
# file holds only what is specific to the Pro 8X: board registration, device
# tree, U-Boot, the MaxLinear switch and Aeonsemi PHY, flash environment and
# first-boot fixes.
#
# The BPI-R4 LED overlay (470/471) and mtk-led-fix are deliberately NOT used
# here: the Pro 8X has its own device tree and a different switch, and two
# descriptions of the same pins is how a board stops booting.
#
# Usage: ./build-bpi-r4-pro-8x.sh    (see BUILD.md for requirements and options)
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
BOARD=bpi-r4-pro-8x
. "$REPO/scripts/common.sh"

em_require_clean_repo
em_fetch_sources
em_patch_mtk_feed
em_prepare                                    # now in $WORK_DIR/openwrt

# Register the board for sysupgrade. Fail closed: if upstream changed the
# list, stop rather than guess.
python3 - <<'PLATFORM_EOF'
f = "target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh"
c = open(f).read()
p1 = "\tbananapi,bpi-r4-lite|\\\n\tbazis,ax3000wm"
p2 = "\tbananapi,bpi-r4-lite|\\\n\tcmcc,rax3000m"
assert c.count(p1) == 2 and c.count(p2) == 1, "platform.sh: upstream changed"
c = c.replace(p1, "\tbananapi,bpi-r4-lite|\\\n\tbananapi,bpi-r4-pro-8x|\\\n\tbazis,ax3000wm")
c = c.replace(p2, "\tbananapi,bpi-r4-lite|\\\n\tbananapi,bpi-r4-pro-8x|\\\n\tcmcc,rax3000m")
open(f, "w").write(c)
assert c.count("bananapi,bpi-r4-pro-8x") == 3
print("platform.sh: bpi-r4-pro-8x registered 3x - OK")
PLATFORM_EOF

# MTK feed patches superseded by ours for this board:
#  - 999-eth-06 passive mux and 046-v6.19 device tree: replaced by our ports
#    (999-eth-01/02, 046/047).
#  - 999-dsa-08: MTK's port of the same Sinovoip ds-mux code we carry as
#    999-dsa-07; both would apply the same change twice and break the build.
#  - MTK's bpi-r4-pro DTS uses the same compatible as our 046; two device
#    trees with one board identity confuse board detection in fit.sh.
P=target/linux/mediatek/patches-6.12
rm -f "$P/999-eth-06-mtk_eth_soc-support-ethernet-passive-mux.patch" \
      "$P/046-v6.19-arm64-dts-mediatek-mt7988a-bpi-r4-pro-add-dts.patch" \
      "$P/999-dsa-08-add-mxl862xx-serdes-port1-mux-selection.patch" \
      "$P/999-dts-mt7988a-bananapi-bpi-r4-pro-01-arm64-dts-mediatek-add-bananapi-bpi-r4-pro-support.patch"

em_install_board_files

cp "$BOARD_DIR/uboot-mediatek-Makefile" package/boot/uboot-mediatek/Makefile
mv target/linux/mediatek/image/filogic-extra.mk target/linux/mediatek/image/filogic-extra.mk.disabled
echo "CONFIG_TASK_IO_ACCOUNTING=y" >> target/linux/mediatek/filogic/config-6.12
# Aeonsemi AS21xxx 10G PHY: the module is aeon_as21xxx.ko, loaded as a module.
python3 -c 'c=open("package/kernel/linux/modules/netdevices.mk").read(); open("package/kernel/linux/modules/netdevices.mk","w").write(c.replace("as21xxx.ko","aeon_as21xxx.ko").replace("AutoLoad,18,as21xxx)","AutoLoad,18,aeon_as21xxx)"))'
python3 -c 'c=open("target/linux/mediatek/filogic/config-6.12").read(); open("target/linux/mediatek/filogic/config-6.12","w").write(c.replace("CONFIG_AS21XXX_PHY=y","CONFIG_AS21XXX_PHY=m"))'
chmod +x files/etc/uci-defaults/* files/lib/preinit/* files/usr/sbin/*

em_setup_feeds

# The Pro 8X delta is not a full configuration: the production package set
# comes from the BPI-R4 config and the board delta goes on top (kconfig takes
# the last occurrence, so the delta wins).
cp "$REPO/configs/bpi-r4.config" .config
cat "$REPO/configs/bpi-r4-pro-8x.delta.config" >> .config
make defconfig
em_apply_defconfig
em_bake_config
em_finish_config

em_build
em_archive
