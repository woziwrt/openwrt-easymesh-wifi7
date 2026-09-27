# shellcheck shell=bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# Everything both boards share: sources, Wi-Fi patches, the iopsys Multi-AP
# stack, our EasyMesh feed, the package set and the checks before the build.
#
# The board scripts (build-bpi-r4.sh, build-bpi-r4-pro-8x.sh) contain only
# what makes a board different: device tree, U-Boot, image layout, ethernet
# PHYs and first-boot files. Anything that affects Wi-Fi or the mesh lives
# here, so the two images cannot drift apart - they did once, for nine days,
# when each builder carried its own copy.
#
# Set by the caller before sourcing: REPO (repository root), BOARD.
# Optional environment:
#   WORK_DIR     build tree            (default: $REPO/build/$BOARD)
#   DL_DIR       download cache        (default: $REPO/dl, shared by both boards)
#   MIRROR_DIR   local git mirrors     (default: $HOME/mirrors, used if present)
#   OUTPUT_DIR   finished images       (default: $REPO/output)
#   ALLOW_DIRTY=1  build from a repository with uncommitted changes
#   LOG_FILE     build log               (default: $OUTPUT_DIR/build-<board>-<time>.log)
# Any of these can also be set once in $REPO/local.conf (not tracked by git).

# shellcheck source=/dev/null
[ -f "$REPO/local.conf" ] && . "$REPO/local.conf"
# shellcheck source=../pins.conf
. "$REPO/pins.conf"

WORK_DIR=${WORK_DIR:-$REPO/build/$BOARD}
DL_DIR=${DL_DIR:-$REPO/dl}
MIRROR_DIR=${MIRROR_DIR:-$HOME/mirrors}
OUTPUT_DIR=${OUTPUT_DIR:-$REPO/output}
BOARD_DIR=$REPO/boards/$BOARD
MTK_MAC80211=mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files
MTK_KERNEL_PATCHES=mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12

em_die() { echo "ERROR: $*" >&2; exit 1; }
em_ok()  { echo ">>> $*"; }

# Everything the build prints also goes to a log file, so no `| tee` is needed.
em_start_log() {
	mkdir -p "$OUTPUT_DIR"
	LOG_FILE=${LOG_FILE:-$OUTPUT_DIR/build-$BOARD-$(date +%Y-%m-%d-%H%M).log}
	exec > >(tee -a "$LOG_FILE") 2>&1
	em_ok "log: $LOG_FILE"
}

# --- 0) what is built must be reproducible -----------------------------------
# An image built from uncommitted files cannot be built again, and nobody can
# tell afterwards what it contained.
em_require_clean_repo() {
	local rev
	rev=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo "not a git checkout")
	if [ -n "$(git -C "$REPO" status --porcelain 2>/dev/null)" ]; then
		git -C "$REPO" status --porcelain | sed 's/^/    /' >&2
		[ "${ALLOW_DIRTY:-0}" = 1 ] || em_die "uncommitted changes in $REPO - commit them or set ALLOW_DIRTY=1"
		echo "WARNING: building from uncommitted changes ($rev) - this image is not reproducible" >&2
	else
		em_ok "repository clean at $rev"
	fi
}

# --- 1) sources at their pins ------------------------------------------------
# Objects are borrowed from local mirrors when they exist (--reference-if-able):
# a fresh openwrt clone measured 737 kB/s against 6.3 MB/s for plain curl, and
# with a mirror it takes seconds. Without mirrors the clone simply downloads.
#   git clone --mirror https://github.com/openwrt/openwrt.git          ~/mirrors/openwrt.git
#   git clone --mirror https://github.com/mediatek/mtk-openwrt-feeds    ~/mirrors/mtk-feeds.git
#   git clone --mirror https://dev.iopsys.eu/feed/iopsys.git           ~/mirrors/iopsys.git
# Do not delete a mirror while a build tree refers to it (.git/objects/info/alternates).
em_clone() {  # url branch commit dir mirror
	git clone --reference-if-able "$MIRROR_DIR/$5" --branch "$2" "$1" "$4" \
		|| em_die "clone of $1 failed"
	git -C "$4" checkout -q "$3" || em_die "$4: pin $3 not found"
	em_ok "$4 at $3"
}

em_fetch_sources() {
	mkdir -p "$WORK_DIR" "$DL_DIR"
	cd "$WORK_DIR" || em_die "cannot enter $WORK_DIR"
	rm -rf openwrt mtk-openwrt-feeds iopsys-feed

	em_clone "$OPENWRT_URL" "$OPENWRT_BRANCH" "$OPENWRT_COMMIT" openwrt openwrt.git
	em_clone "$MTK_URL" "$MTK_BRANCH" "$MTK_COMMIT" mtk-openwrt-feeds mtk-feeds.git

	# Downloads outside the tree, from the first byte: the tree is deleted on
	# every build, and CONFIG_DOWNLOAD_FOLDER would only take effect after
	# `autobuild.sh prepare`, which already downloads.
	ln -sfn "$DL_DIR" openwrt/dl

	# Feeds from GitHub, not git.openwrt.org: the latter answered 504 twice in
	# one hour on 2026-08-20 and took two builds down. Same commits either way.
	sed -i -e "s|https://git.openwrt.org/feed/|https://github.com/openwrt/|g" \
	       -e "s|https://git.openwrt.org/project/|https://github.com/openwrt/|g" \
	       openwrt/feeds.conf.default

	em_setup_iopsys_tree
}

# iopsys upstream at IOPSYS_BASE plus our overlay. The resulting tree must hash
# to IOPSYS_TREE; anything else means a file was lost or changed on the way.
em_setup_iopsys_tree() {
	git clone --reference-if-able "$MIRROR_DIR/iopsys.git" "$IOPSYS_URL" iopsys-feed \
		|| em_die "clone of $IOPSYS_URL failed"
	git -C iopsys-feed checkout -q "$IOPSYS_BASE" || em_die "iopsys: base $IOPSYS_BASE not found"
	cp -a "$REPO/iopsys/overlay/." iopsys-feed/
	local tree
	tree=$(cd iopsys-feed && git add -A && git write-tree)
	[ "$tree" = "$IOPSYS_TREE" ] || em_die "iopsys tree is $tree, expected $IOPSYS_TREE (overlay incomplete or changed)"
	em_ok "iopsys: upstream $IOPSYS_BASE + overlay = tree $tree"
}

# --- 2) patches into the MediaTek feed (before autobuild prepare) ------------
em_patch_mtk_feed() {
	cd "$WORK_DIR" || em_die "cannot enter $WORK_DIR"
	local p

	# mt76-vendor: air-monitor MAC as six bytes, not a nest of six u8 - without
	# it `mt76-vendor <dev> set amnt <idx> <mac>` always fails with EINVAL.
	patch -p1 -d mtk-openwrt-feeds < "$REPO/patches/mtk-feed/999-vendor-01-amnt-macaddr-flat.patch" \
		|| em_die "999-vendor-01 does not apply"

	# Board-specific patches to the MTK feed itself (e.g. EIP crypto on BPI-R4).
	for p in "$BOARD_DIR"/mtk-feed/*.patch; do
		[ -f "$p" ] || continue
		patch -p1 -d mtk-openwrt-feeds < "$p" || em_die "$(basename "$p") does not apply"
	done

	# Kernel patches that must sit in the MTK feed before prepare copies it
	# into the OpenWrt tree: SFP quirks, RTL8261BE probe, GMAC RX hang, LynxI PCS.
	cp "$REPO"/patches/mtk-feed/kernel/*.patch "$MTK_KERNEL_PATCHES/"

	# The MTK feed ships cmake_minimum_required(VERSION 2.8); CMake 4.x refuses
	# anything below 3.5. Same fix OpenWrt uses for libjson-c.
	sed -i "s/^cmake_minimum_required(VERSION 2\.8)/cmake_minimum_required(VERSION 3.5)/" \
		mtk-openwrt-feeds/feed/app/mt76-vendor/src/CMakeLists.txt

	em_apply_wifi_patches
}

# Wi-Fi patches - identical on every node, whatever the board.
# Why each one exists is in its own commit message (patches/wifi/*.patch).
em_apply_wifi_patches() {
	local W="$REPO/patches/wifi"
	local HP="$MTK_MAC80211/package/network/services/hostapd"
	local MT="$MTK_MAC80211/package/kernel/mt76/patches"
	local p

	cp "$W/999-fix-01-mac80211-btwt-ap-mode.patch" \
		"$MTK_MAC80211/package/kernel/mac80211/patches/subsys/0999-fix-mac80211-btwt-ap-mode-he-btwt-supported.patch"

	for p in 0264-wpa_s-add-btwt-join-command 0266-mld-find-sta-pending-assoc \
	         0267-mld-link-aid-offset 0268-mld-link-free-keeps-aid \
	         0269-ttlm-ctrl-iface-parser-fixes 0272-ctrl-iface-replies-must-not-block \
	         0273-neg-ttlm-request-element-length 0274-neg-ttlm-keep-dialog-token-across-parse \
	         0275-neg-ttlm-request-no-uninitialised-pointers; do
		cp "$W/$p.patch" "$HP/patches/$p.patch"
	done

	# These two change MTK's overlay of hostapd/files (ucode scripts), which is
	# not a patch series, so they are applied directly.
	for p in 0270-wpa_supplicant-apsta-keep-aps-on-mesh-node 0271-hostapd-restart-mld-sibling-radios; do
		patch -p1 -N -d "$HP/files" < "$W/$p.patch" || em_die "$p does not apply"
	done

	# 0118 is a backport of MTK 73e7f7db under MTK's own file name, so moving
	# the pin past that commit replaces this copy instead of applying it twice.
	cp "$W/0118-cp-mtk-mt76-mt7996-Update-wcid-idx-when-sending-null-fu.patch" "$MT/"
	cp "$W/999-wifi-01-mt7996-per-band-leds.patch" "$MT/9999-w-mt7996-per-band-leds.patch"
	cp "$W/999-wifi-02-mt76-share-tpt-led-trigger.patch" "$MT/9999-w-mt76-share-tpt-led-trigger.patch"
	em_ok "Wi-Fi patches in place"
}

em_prepare() {
	cd "$WORK_DIR/openwrt" || em_die "no openwrt tree"
	bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh "$AUTOBUILD_TARGET" prepare
}

# --- 3) board files into the prepared tree (run in openwrt/) -----------------
em_install_board_files() {
	local p
	cp "$REPO"/patches/kernel/*.patch target/linux/mediatek/patches-6.12/
	cp "$REPO"/patches/uboot/*.patch package/boot/uboot-mediatek/patches/
	for p in "$BOARD_DIR"/patches-kernel/*.patch; do [ -f "$p" ] && cp "$p" target/linux/mediatek/patches-6.12/; done
	for p in "$BOARD_DIR"/patches-uboot/*.patch;  do [ -f "$p" ] && cp "$p" package/boot/uboot-mediatek/patches/; done
	cp "$BOARD_DIR/filogic.mk" target/linux/mediatek/image/filogic.mk
	cp "$REPO/boards/common/arm-trusted-firmware-mediatek-Makefile" package/boot/arm-trusted-firmware-mediatek/Makefile
	echo "CONFIG_BLK_DEV_NVME=y" >> target/linux/mediatek/filogic/config-6.12

	# Files baked into the image: common first, then the board's own.
	mkdir -p files
	cp -a "$REPO/boards/common/files/." files/
	[ -d "$BOARD_DIR/files" ] && cp -a "$BOARD_DIR/files/." files/
	mkdir -p files/root/install-dir
	cp "$BOARD_DIR"/install/install-*.sh files/root/install-dir/
	chmod +x files/root/install-dir/*.sh

	# Image model, read by easymesh-config: a production image has the mesh
	# baked in and must never point itself at a development package feed.
	echo production > files/etc/easymesh-model
}

# --- 4) feeds: upstream, iopsys, ours (run in openwrt/) ----------------------
em_setup_feeds() {
	local f
	./scripts/feeds update -a
	# `feeds update` can fail half-way and the build then breaks sixty lines
	# later somewhere unrelated. Check what exists, not what was asked for.
	for f in packages luci routing; do
		[ -d "feeds/$f" ] || em_die "feeds/$f missing - feed clone failed"
	done
	em_ok "feeds packages, luci, routing cloned"
	./scripts/feeds install -a

	echo "src-link iopsys $WORK_DIR/iopsys-feed" >> feeds.conf.default
	./scripts/feeds update iopsys
	./scripts/feeds install libeasy libwifiutils libwifi libieee1905 ieee1905 \
		ieee1905-map-plugin wifimngr map-controller map-agent

	echo "src-link easymeshr6 $REPO/feed" >> feeds.conf.default
	./scripts/feeds update easymeshr6
	./scripts/feeds install easymesh easymesh-core easymesh-config easymesh-mesh \
		easymesh-wifi easymesh-api easymesh-trace luci-app-easymesh luci-app-wifimgr

	cp "$BOARD_DIR/fit.sh" package/utils/fitblk/files/fit.sh
	em_fix_wifi_scripts
}

# wifi-scripts: `config.wpa_psk = key` is a typo for `config.key`. It runs only
# for a passphrase of exactly 64 characters, then ucode throws on the undeclared
# variable and the whole radio stays down - it looks exactly like a driver fault.
# Guarded: a no-op once upstream fixes it, and a stop if the line changes shape.
em_fix_wifi_scripts() {
	local f=package/network/config/wifi-scripts/files-ucode/usr/share/ucode/wifi/ap.uc
	if grep -q 'config\.wpa_psk = key;' "$f"; then
		sed -i 's/config\.wpa_psk = key;/config.wpa_psk = config.key;/' "$f"
		em_ok "wifi-scripts: ap.uc fixed (config.wpa_psk = key -> config.key)"
	elif grep -q 'config\.wpa_psk = config\.key;' "$f"; then
		em_ok "wifi-scripts: ap.uc already correct upstream"
	else
		em_die "ap.uc has neither the bug nor the fix - upstream changed, check $f"
	fi
}

# --- 5) configuration --------------------------------------------------------
# The iopsys stack and tools every node needs.
em_apply_defconfig() {
	cat >> .config <<'EASYMESH_EOF'
CONFIG_PACKAGE_libeasy=y
CONFIG_PACKAGE_libwifi=y
CONFIG_PACKAGE_libwifiutils=y
CONFIG_PACKAGE_libieee1905=y
CONFIG_PACKAGE_ieee1905=y
CONFIG_PACKAGE_ieee1905-map-plugin=y
CONFIG_PACKAGE_wifimngr=y
CONFIG_PACKAGE_map-agent=y
CONFIG_PACKAGE_kmod-ebtables=y
CONFIG_PACKAGE_map-controller=y
CONFIG_PACKAGE_wpad-openssl=y
CONFIG_PACKAGE_hostapd-common=y
CONFIG_PACKAGE_hostapd-utils=y
CONFIG_PACKAGE_wpa-cli=y
# udebug: ring buffers of hostapd/wpa_supplicant nl80211 + log, netifd, procd
# and kernel log on one timeline (`udebug -o x.pcapng snapshot`), off until
# enabled in /etc/config/udebug. netsys_dbg_util: MTK register dump of the
# ethernet/WED path.
CONFIG_PACKAGE_udebugd=y
CONFIG_PACKAGE_udebug-cli=y
CONFIG_PACKAGE_ucode-mod-udebug=y
CONFIG_PACKAGE_netsys_dbg_util=y
# Kernel tracing: ftrace + mac80211/cfg80211 tracepoints and kprobe events, to
# see a frame as it reaches cfg80211 without a rebuild. Dynamic ftrace costs
# nothing while no tracer is on.
CONFIG_KERNEL_FTRACE=y
CONFIG_KERNEL_ENABLE_DEFAULT_TRACERS=y
CONFIG_KERNEL_FUNCTION_TRACER=y
CONFIG_KERNEL_DYNAMIC_FTRACE=y
CONFIG_KERNEL_KPROBES=y
CONFIG_KERNEL_KPROBE_EVENTS=y
CONFIG_PACKAGE_MAC80211_TRACING=y
CONFIG_AGENT_EASYMESH_VERSION=6
CONFIG_CONTROLLER_EASYMESH_VERSION=6
CONFIG_MULTIAP_EASYMESH_VERSION=6
CONFIG_IEEE1905_ETH_MEDIA_EXTENSION=y
CONFIG_IEEE1905_EXTENSION_ALLOWED=y
CONFIG_IEEE1905_PLATFORM_HAS_WIFI=y
CONFIG_IEEE1905_WIFI_EASYMESH=y
CONFIG_LIBWIFI_SKIP_PROBES=y
CONFIG_LIBWIFI_USE_CTRL_IFACE=y
CONFIG_WIFIMNGR_CACHE_SCANRESULTS=y
CONFIG_WIFIMNGR_VENDOR_EXTENSIONS=y
CONFIG_WIFIMNGR_VENDOR_PREFIX="X_IOWRT_EU_"
CONFIG_PACKAGE_libsqlite3=y
CONFIG_PACKAGE_sqlite3-cli=y
CONFIG_PACKAGE_strace=y
CONFIG_PACKAGE_gdb=y
CONFIG_PACKAGE_gdbserver=y
CONFIG_PACKAGE_python3-light=y
# CONFIG_PACKAGE_dm-service is not set
# CONFIG_PACKAGE_libbbfdm-api is not set
# CONFIG_PACKAGE_libbbfdm-ubus is not set
# CONFIG_PACKAGE_bbf_configmngr is not set
CONFIG_BUSYBOX_CUSTOM=y
CONFIG_BUSYBOX_CONFIG_TIMEOUT=y
CONFIG_PACKAGE_luci-app-wifimgr=y
EASYMESH_EOF
	make defconfig
	# TR-181 plugins and libdpp off (the defconfig enables them by default),
	# then dm-service and libbbfdm-* - only after the plugins, which pull them in.
	sed -i -e "s/^CONFIG_IEEE1905_BUILD_TR181_PLUGIN=y/# CONFIG_IEEE1905_BUILD_TR181_PLUGIN is not set/" \
	       -e "s/^CONFIG_WIFIMNGR_BUILD_TR181_PLUGIN=y/# CONFIG_WIFIMNGR_BUILD_TR181_PLUGIN is not set/" \
	       -e "s/^CONFIG_AGENT_USE_LIBDPP=y/# CONFIG_AGENT_USE_LIBDPP is not set/" \
	       -e "s/^CONFIG_CONTROLLER_USE_LIBDPP=y/# CONFIG_CONTROLLER_USE_LIBDPP is not set/" .config
	sed -i -e "s/^CONFIG_PACKAGE_dm-service=y/# CONFIG_PACKAGE_dm-service is not set/" \
	       -e "s/^CONFIG_PACKAGE_libbbfdm-api=y/# CONFIG_PACKAGE_libbbfdm-api is not set/" \
	       -e "s/^CONFIG_PACKAGE_libbbfdm-ubus=y/# CONFIG_PACKAGE_libbbfdm-ubus is not set/" .config
	make defconfig
}

# The production image has the whole mesh baked in (=y): a user has no package
# feed and no reason to run apk, so the image must work the moment it boots and
# the upgrade path is sysupgrade. Baking the stack in AND installing it from apk
# on top is what once made no two lab nodes alike - the two must not be mixed.
em_bake_config() {
	cat >> .config <<'BAKE_EOF'
# Not a package: 1905 frames must carry the AL-MAC as source address.
CONFIG_IEEE1905_CMDU_SA_IS_ALMAC=y
# SDK and ImageBuilder: a change in a userspace package then costs seconds to
# rebuild and minutes to re-assemble an image, instead of a full build. Valid
# only for the pins they were built from. IB_STANDALONE makes the ImageBuilder
# carry its own repository - without it, it points at downloads.openwrt.org,
# where our feeds do not exist.
CONFIG_SDK=y
CONFIG_IB=y
CONFIG_IB_STANDALONE=y
CONFIG_PACKAGE_netsys_dbg_util=y
# memdump: memory dump through ATF on a kernel PANIC (not on a watchdog reset).
CONFIG_PACKAGE_kmod-memdump-cfg=y
# mesh-gwd flushes conntrack when the gateway moves, so clients do not wait
# 30-90 s for flows built for the old path to expire.
CONFIG_PACKAGE_conntrack=y
# Without topology.so ieee1905d loads only map.so and the topology view can
# show nothing but MAC addresses (no names, models or addresses).
CONFIG_PACKAGE_ieee1905-topology-plugin=y
CONFIG_PACKAGE_easymesh=y
CONFIG_PACKAGE_easymesh-api=y
CONFIG_PACKAGE_easymesh-config=y
CONFIG_PACKAGE_easymesh-mesh=y
CONFIG_PACKAGE_easymesh-wifi=y
# Listed by hand although easymesh-api depends on it: lines appended after
# `make defconfig` never get their dependencies resolved otherwise.
CONFIG_PACKAGE_easymesh-core=y
CONFIG_PACKAGE_luci-app-easymesh=y
CONFIG_PACKAGE_luci-app-wifimgr=y
CONFIG_PACKAGE_kmod-mdio-netlink=y
CONFIG_PACKAGE_mdio-tools=y
# MTK SMP/RPS tuning: without it every ethernet interrupt sits on cpu0 and a
# 10G link gives ~5.4 instead of ~9.4 Gbit/s (iperf3, 2026-08-30).
CONFIG_PACKAGE_smp_util=y
CONFIG_PACKAGE_luci-app-tailscale-community=y
# mt76 vendor CLI: `amnt` (air monitor) measures the signal of up to 16
# stations that are NOT associated - how well a node hears candidate parents
# before the backhaul is moved. A second, independent instrument next to `iw`.
CONFIG_PACKAGE_mt76-vendor=y
# IPsec hardware offload, look-aside (inline measured slower: 1.21 vs 1.9 Gb/s).
# The firmware must be selected explicitly: `+eip197-mini-firmware` in Depends
# is enforced by apk at install time, but `make defconfig` does not add it.
CONFIG_PACKAGE_kmod-crypto-hw-safexcel=y
CONFIG_PACKAGE_eip197-mini-firmware=y
BAKE_EOF
}

# Check what `make defconfig` actually produced, not what we asked for: kconfig
# silently drops anything whose dependencies are not met. tail -1 because a
# symbol can appear twice and kconfig takes the last one.
em_config_value() { grep -E "^(# )?CONFIG_$1[= ]" .config | tail -1 || true; }

em_check_config() {
	local s v missing=""
	for s in libeasy libwifi libwifiutils libieee1905 ieee1905 ieee1905-map-plugin \
	         wifimngr map-agent map-controller hostapd-utils wpa-cli \
	         easymesh easymesh-core easymesh-api easymesh-config easymesh-mesh easymesh-wifi \
	         luci-app-easymesh luci-app-wifimgr conntrack ieee1905-topology-plugin \
	         smp_util luci-app-tailscale-community kmod-crypto-hw-safexcel eip197-mini-firmware; do
		v=$(em_config_value "PACKAGE_$s")
		case "$v" in *"=y") ;; *) em_die "CONFIG_PACKAGE_$s is not =y (${v:-missing}) - the image would lack it" ;; esac
	done
	em_ok "mesh stack, crypto offload and tuning packages are =y"

	# mwan3 must not come back (it breaks strongSwan); a dependency of
	# prometheus-node-exporter-lua-mwan3 would pull it in silently.
	for s in mwan3 luci-app-mwan3; do
		case "$(em_config_value "PACKAGE_$s")" in *"=y") em_die "CONFIG_PACKAGE_$s is =y - something pulled mwan3 back in" ;; esac
	done
	em_ok "mwan3 not in the image"

	# User add-ons: warn, do not stop. ppp/pppoe are here because the target
	# profile pulls them in and nothing else would notice them missing.
	for s in kmod-fs-exfat kmod-fs-ntfs3 ddns-scripts luci-app-ddns \
	         miniupnpd-nftables luci-app-upnp nlbwmon luci-app-nlbwmon \
	         luci-app-wol adblock luci-app-adblock luci-proto-wireguard \
	         kmod-macvlan kmod-usb-storage-uas kmod-usb-net-ipheth usbmuxd \
	         hd-idle luci-app-hd-idle kmod-usb-printer p910nd luci-app-p910nd \
	         minidlna luci-app-minidlna tailscale zerotier kmod-vxlan kmod-bonding \
	         ppp ppp-mod-pppoe kmod-pppoe; do
		case "$(em_config_value "PACKAGE_$s")" in *"=y") ;; *) missing="$missing $s" ;; esac
	done
	if [ -n "$missing" ]; then
		echo "WARNING: these add-ons did not make it into the image:$missing" >&2
	else
		em_ok "all user add-ons are in the image"
	fi

	# A build with no device selected reports success and produces no image.
	v=$(grep -c "^CONFIG_TARGET_DEVICE_.*=y" .config || true)
	[ "$v" -gt 0 ] || em_die "no device selected - check that filogic.mk defines the board"
	em_ok "devices selected: $v"
}

em_finish_config() {
	make defconfig
	em_check_config
	# The DDR4 "comb-4bg" boot loaders for the 8 GB boards go in AFTER the last
	# `make defconfig`: defconfig drops these three symbols (they are not
	# selectable through the menu), and without them the bpi-r4-poe-8gb eMMC
	# and SD images fail at the very end on a missing mt7988-*-comb-4bg-bl2.img
	# (2026-09-27, first build of this repository).
	echo "CONFIG_PACKAGE_trusted-firmware-a-mt7988-emmc-comb-4bg=y" >> .config
	echo "CONFIG_PACKAGE_trusted-firmware-a-mt7988-sdmmc-comb-4bg=y" >> .config
	echo "CONFIG_PACKAGE_trusted-firmware-a-mt7988-spim-nand-ubi-comb-4bg=y" >> .config
}

em_build() {
	bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh "$AUTOBUILD_TARGET" build
}

# --- 6) output ---------------------------------------------------------------
# The build tree is deleted by the next build, including the SDK and
# ImageBuilder that took hours, so everything worth keeping is copied out,
# together with the exact revisions it was built from.
em_archive() {
	local root="$WORK_DIR/openwrt" stamp dst f
	[ -d "$root/bin/targets" ] || { echo "WARNING: no bin/targets under $root" >&2; return 0; }
	stamp=$(date +%Y-%m-%d-%H%M)
	dst="$OUTPUT_DIR/$stamp-$BOARD"
	mkdir -p "$dst/images" "$dst/packages" "$dst/sdk"

	find "$root/bin/targets" \( -name '*.itb' -o -name '*.img.gz' \) -exec cp {} "$dst/images/" \;
	# eMMC and NAND images are .bin (~188 MB unpacked); the NVMe image (592 MB)
	# is installed another way and left out.
	for f in "$root"/bin/targets/*/*/*emmc-img.bin "$root"/bin/targets/*/*/*snand-img.bin; do
		[ -f "$f" ] && gzip -c "$f" > "$dst/images/$(basename "$f").gz"
	done
	find "$root/bin/packages" -name '*.apk' \( -path '*easymeshr6*' -o -path '*iopsys*' \) \
		-exec cp {} "$dst/packages/" \;
	for f in "$root"/bin/targets/*/*/openwrt-sdk-*.tar.zst "$root"/bin/targets/*/*/openwrt-imagebuilder-*.tar.zst \
	         "$root"/bin/targets/*/*/*.manifest; do
		[ -f "$f" ] && cp "$f" "$dst/sdk/"
	done
	# The ImageBuilder builds whatever it is told to, silently: the package list
	# must travel with it or a re-assembled image comes out a fraction of the size.
	for f in "$dst"/sdk/*.manifest; do
		[ -f "$f" ] && { awk '{print $1}' "$f" | tr '\n' ' '; echo; } > "$dst/sdk/PACKAGES.txt"
	done
	( cd "$dst/sdk" && md5sum *.tar.zst > MD5SUMS.txt 2>/dev/null ) || true
	# files/ overlay: without it an image re-assembled from the ImageBuilder
	# boots and looks right, but lacks hostname, model and rootfs expansion.
	[ -d "$root/files" ] && cp -a "$root/files" "$dst/files" && ( cd "$dst" && find files -type f | sort > FILES.txt )

	{
		echo "board   : $BOARD"
		echo "built   : $stamp"
		echo "repo    : $(git -C "$REPO" rev-parse HEAD 2>/dev/null)"
		echo ""
		echo "REVISIONS - the image cannot be rebuilt without these"
		printf "  %-18s %s\n" openwrt "$(git -C "$root" rev-parse HEAD)"
		printf "  %-18s %s\n" mtk-openwrt-feeds "$(git -C "$WORK_DIR/mtk-openwrt-feeds" rev-parse HEAD)"
		printf "  %-18s %s + overlay (tree %s)\n" iopsys "$IOPSYS_BASE" "$IOPSYS_TREE"
		for f in packages luci routing telephony video; do
			[ -d "$root/feeds/$f/.git" ] && printf "  %-18s %s\n" "feeds/$f" "$(git -C "$root/feeds/$f" rev-parse HEAD)"
		done
	} > "$dst/MANIFEST.txt"
	em_ok "output: $dst ($(du -sh "$dst" | cut -f1))"
}
