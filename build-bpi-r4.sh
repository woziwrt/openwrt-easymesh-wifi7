#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# Production image for the Banana Pi BPI-R4 (4 GB and 8 GB) with the EasyMesh
# stack baked in. Everything about Wi-Fi and the mesh is in scripts/common.sh;
# this file holds only what is specific to the BPI-R4 board.
#
# Usage: ./build-bpi-r4.sh    (see BUILD.md for requirements and options)
set -euo pipefail
REPO=$(cd "$(dirname "$0")" && pwd)
BOARD=bpi-r4
. "$REPO/scripts/common.sh"

em_start_log
em_require_clean_repo
em_fetch_sources
em_patch_mtk_feed
em_prepare                                    # now in $WORK_DIR/openwrt

em_install_board_files

# Front-panel and port LEDs: device tree overlay + U-Boot LED + PHY trigger,
# and mtk-led-fix programs the mt7530 gphy port-LED registers at boot.
sed -i 's/mt7988a-bananapi-bpi-r4-nvme$/mt7988a-bananapi-bpi-r4-nvme mt7988a-bananapi-bpi-r4-leds/' \
	target/linux/mediatek/image/filogic.mk
echo "CONFIG_LED_TRIGGER_PHY=y" >> target/linux/mediatek/filogic/config-6.12
chmod +x files/etc/init.d/* files/etc/uci-defaults/* files/lib/preinit/*

em_setup_feeds

cp "$REPO/configs/bpi-r4.config" .config
make defconfig
em_apply_defconfig
em_bake_config

# MTK EIP crypto driver: built so it can be compared with safexcel, but NOT
# loaded at boot (no kmod-crypto-eip-autoload) - both would fight over the same
# EIP197. Needs boards/bpi-r4/mtk-feed/999-crypto-01. To try it by hand:
#   rmmod crypto_safexcel && modprobe crypto-eip-inline
cat >> .config <<'EOF'
CONFIG_CRYPTO_OFFLOAD_INLINE=y
CONFIG_CRYPTO_OFFLOAD_INLINE_FLOWBLOCK=y
CONFIG_PACKAGE_kmod-crypto-eip=y
CONFIG_PACKAGE_kmod-crypto-eip-ddk=y
CONFIG_PACKAGE_kmod-crypto-eip-ddk-ksupport=y
CONFIG_PACKAGE_kmod-crypto-eip-ddk-ctrl=y
CONFIG_PACKAGE_kmod-crypto-eip-ddk-ctrl-app=y
CONFIG_PACKAGE_kmod-crypto-eip-ddk-engine=y
CONFIG_PACKAGE_kmod-crypto-eip-inline=y
CONFIG_PACKAGE_crypto-eip-inline-fw=y
EOF

em_finish_config

# The MTK EIP driver is optional: report, do not stop.
_miss=""
for _s in PACKAGE_kmod-crypto-eip PACKAGE_kmod-crypto-eip-inline PACKAGE_crypto-eip-inline-fw \
          CRYPTO_OFFLOAD_INLINE CRYPTO_OFFLOAD_INLINE_FLOWBLOCK; do
	case "$(em_config_value "$_s")" in *"=y") ;; *) _miss="$_miss $_s" ;; esac
done
[ -z "$_miss" ] && em_ok "MTK EIP driver is =y (loaded by hand only)" \
	|| echo "WARNING: MTK EIP driver not selected:$_miss - image is fine, only the comparison is not possible" >&2

em_build
em_archive
