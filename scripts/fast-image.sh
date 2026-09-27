#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# An image in minutes instead of an hour, from the last full build of a board.
#
#   scripts/fast-image.sh <device> [full-build-output]
#     device: bananapi_bpi-r4, bananapi_bpi-r4-8gb, bananapi_bpi-r4-poe,
#             bananapi_bpi-r4-poe-8gb, bananapi_bpi-r4-pro-8x, ...
#
# What it takes from this repository:
#   - feed/ EasyMesh packages       recompiled in the full build's SDK
#   - feed/luci-app-*               laid over the image as files
#   - patches/wifi/ 0270 0271 0276  the hostapd ucode scripts they patch,
#                                   laid over the image as files
#   - patches/luci/                 the LuCI files they patch, laid over
# Everything else comes from the full build as it was: kernel, drivers,
# hostapd and iopsys binaries, every other package. A change to any of those
# (or to pins.conf, iopsys/overlay, configs, boards) needs build-*.sh - this
# script refuses when the pins or the iopsys tree differ from the full build.
#
# The image is for testing. Releases are made from full builds.

set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$REPO/local.conf" ] && . "$REPO/local.conf"
. "$REPO/pins.conf"
WORK_BASE=${WORK_DIR_BASE:-$REPO/build}
OUTPUT_DIR=${OUTPUT_DIR:-$REPO/output}
DL_DIR=${DL_DIR:-$REPO/dl}

die() { echo "ERROR: $*" >&2; exit 1; }
ok()  { echo ">>> $*"; }

DEVICE=${1:-}
case "$DEVICE" in
bananapi_bpi-r4-pro-8x) BOARD=bpi-r4-pro-8x ;;
bananapi_bpi-r4*)       BOARD=bpi-r4 ;;
*) die "usage: $0 <device> [full-build-output]   e.g. bananapi_bpi-r4-8gb" ;;
esac

ARCH=${2:-$(ls -d "$OUTPUT_DIR"/*-"$BOARD" 2>/dev/null | sort | tail -1 || true)}
ARCH=${ARCH%/}
[ -f "$ARCH/MANIFEST.txt" ] || die "no full build output for $BOARD in $OUTPUT_DIR - run build-$BOARD.sh first"
ls "$ARCH"/sdk/openwrt-sdk-*.tar.zst "$ARCH"/sdk/openwrt-imagebuilder-*.tar.zst >/dev/null 2>&1 ||
	die "$ARCH has no SDK or ImageBuilder"
ok "full build: $ARCH"

# The SDK and the ImageBuilder are only valid for the revisions they were
# built from.
rev() { sed -n "s|^  $1  *\([0-9a-f]\{7,\}\).*|\1|p" "$ARCH/MANIFEST.txt" | head -1; }
[ "$(rev openwrt)" = "$OPENWRT_COMMIT" ] || die "OpenWrt pin moved since that build ($(rev openwrt) -> $OPENWRT_COMMIT)"
[ "$(rev mtk-openwrt-feeds)" = "$MTK_COMMIT" ] || die "MTK pin moved since that build ($(rev mtk-openwrt-feeds) -> $MTK_COMMIT)"
grep -q "tree $IOPSYS_TREE" "$ARCH/MANIFEST.txt" || die "iopsys overlay changed since that build (IOPSYS_TREE) - its binaries need a full build"
LUCI_REV=$(rev feeds/luci)
[ -n "$LUCI_REV" ] || die "$ARCH/MANIFEST.txt names no feeds/luci revision"
ok "pins match the full build"

# Sources at the pinned revisions, read from the full build's own trees.
BT="$WORK_BASE/$BOARD"
MTK_GIT="$BT/mtk-openwrt-feeds"
LUCI_GIT="$BT/openwrt/feeds/luci"
git -C "$MTK_GIT" cat-file -e "$MTK_COMMIT^{commit}" 2>/dev/null || die "no MTK feed at $MTK_COMMIT in $MTK_GIT"
git -C "$LUCI_GIT" cat-file -e "$LUCI_REV^{commit}" 2>/dev/null || die "no LuCI feed at $LUCI_REV in $LUCI_GIT"

W="$WORK_BASE/fast/$DEVICE"
mkdir -p "$W"
if [ "$(cat "$W/.from" 2>/dev/null)" != "$ARCH" ]; then
	rm -rf "$W"/openwrt-sdk-* "$W"/openwrt-imagebuilder-*
	ok "unpacking SDK and ImageBuilder"
	tar -I zstd -xf "$ARCH"/sdk/openwrt-sdk-*.tar.zst -C "$W"
	tar -I zstd -xf "$ARCH"/sdk/openwrt-imagebuilder-*.tar.zst -C "$W"
	echo "$ARCH" > "$W/.from"
fi
SDK=$(ls -d "$W"/openwrt-sdk-* | head -1)
IB=$(ls -d "$W"/openwrt-imagebuilder-* | head -1)

# --- 1. feed packages, compiled in the SDK ----------------------------------
# luci-app-* are not compiled here: they include luci.mk, which would pull the
# whole LuCI feed into the SDK. Their files go on as an overlay (step 2).
PKGS_FEED="easymesh easymesh-api easymesh-core easymesh-config easymesh-mesh easymesh-wifi easymesh-trace"
(
	cd "$SDK"
	echo "src-link easymeshr6 $REPO/feed" > feeds.conf
	rm -rf dl && ln -sfn "$DL_DIR" dl
	./scripts/feeds update easymeshr6 >/dev/null
	# shellcheck disable=SC2086
	./scripts/feeds install $PKGS_FEED >/dev/null
	make defconfig >/dev/null
	for p in $PKGS_FEED; do
		make "package/feeds/easymeshr6/$p/clean" >/dev/null 2>&1 || true
		make "package/feeds/easymeshr6/$p/compile" > "$W/compile-$p.log" 2>&1 ||
			{ tail -15 "$W/compile-$p.log" >&2; die "$p does not compile, see $W/compile-$p.log"; }
	done
)
ok "compiled: $PKGS_FEED"

# --- 2. overlay: files that need no compiling --------------------------------
OV="$W/overlay"
rm -rf "$OV" && mkdir -p "$OV"
[ -d "$ARCH/files" ] && cp -a "$ARCH/files/." "$OV/"

# hostapd ucode scripts: MTK's version at the pin + our patches
T="$W/tmp" && rm -rf "$T" && mkdir -p "$T/hostapd"
HPF=autobuild/unified/filogic/mac80211/25.12/files/package/network/services/hostapd/files
for f in wpa_supplicant.uc hostapd.uc; do
	git -C "$MTK_GIT" show "$MTK_COMMIT:$HPF/$f" > "$T/hostapd/$f"
done
for p in 0270-wpa_supplicant-apsta-keep-aps-on-mesh-node 0271-hostapd-restart-mld-sibling-radios \
         0276-wpa_supplicant-apsta-grace-before-stopping-aps; do
	patch -s -p1 -d "$T/hostapd" < "$REPO/patches/wifi/$p.patch" || die "$p does not apply"
done
mkdir -p "$OV/usr/share/hostap"
cp "$T/hostapd/wpa_supplicant.uc" "$T/hostapd/hostapd.uc" "$OV/usr/share/hostap/"

# LuCI files our patches touch: LuCI at the pin + patches/luci
for pf in "$REPO"/patches/luci/*.patch; do
	[ -f "$pf" ] || continue
	for f in $(sed -n 's|^+++ b/||p' "$pf" | cut -f1); do
		mkdir -p "$T/luci/$(dirname "$f")"
		git -C "$LUCI_GIT" show "$LUCI_REV:$f" > "$T/luci/$f"
	done
	patch -s -p1 -d "$T/luci" < "$pf" || die "$(basename "$pf") does not apply"
done
lay() {  # lay <package-dir>: htdocs -> /www, root -> /
	[ -d "$1/htdocs" ] && mkdir -p "$OV/www" && cp -a "$1/htdocs/." "$OV/www/"
	[ -d "$1/root" ] && cp -a "$1/root/." "$OV/"
	return 0
}
[ -d "$T/luci" ] && for d in "$T"/luci/modules/* "$T"/luci/applications/*; do [ -d "$d" ] && lay "$d"; done

# our LuCI apps
for a in luci-app-easymesh luci-app-wifimgr; do
	lay "$REPO/feed/$a"
	v=$(sed -n 's/^PKG_VERSION:=//p' "$REPO/feed/$a/Makefile")
	{ grep -rl '@@PKG_VERSION@@' "$OV/www" 2>/dev/null || true; } | xargs -r sed -i "s/@@PKG_VERSION@@/$v/"
done
ok "overlay: $(find "$OV" -type f | wc -l) files"

# --- 3. image ---------------------------------------------------------------
cp -f "$SDK"/bin/packages/*/easymeshr6/*.apk "$IB/packages/"
PKGS=$(cat "$ARCH/sdk/PACKAGES.txt")
# A fresh build date, or the browser keeps LuCI views of the previous image
# (their URLs carry the build date).
date +%s > "$IB/version.date"
( cd "$IB" && make image PROFILE="$DEVICE" PACKAGES="$PKGS" FILES="$OV" > "$W/image.log" 2>&1 ) ||
	{ tail -20 "$W/image.log" >&2; die "make image failed, see $W/image.log"; }

stamp=$(date +%Y-%m-%d-%H%M)
dst="$OUTPUT_DIR/fast-$stamp-$DEVICE"
mkdir -p "$dst"
cp "$IB"/bin/targets/*/*/*"$DEVICE"-squashfs-sysupgrade.itb "$dst/"
cp "$IB"/bin/targets/*/*/*"$DEVICE"-sdcard.img.gz "$dst/" 2>/dev/null || true
{
	echo "fast image : $DEVICE"
	echo "built      : $stamp"
	echo "repo       : $(git -C "$REPO" rev-parse HEAD)$([ -n "$(git -C "$REPO" status --porcelain)" ] && echo ' (dirty)')"
	echo "full build : $ARCH"
	echo "recompiled : $PKGS_FEED"
	echo "overlay    : hostapd ucode (0270 0271 0276), patches/luci, luci-app-easymesh, luci-app-wifimgr"
	echo "NOT A RELEASE IMAGE - releases come from build-*.sh"
} > "$dst/MANIFEST.txt"
ok "output: $dst"
ls -l "$dst" | awk 'NR>1 {printf "    %7.1f MB  %s\n", $5/1048576, $9}'
