#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#
# Publish finished builds as a GitHub release of this repository.
#
#   scripts/release.sh                    newest BPI-R4 and BPI-R4 Pro 8X output
#   scripts/release.sh <output-dir>...    these outputs (from build-*.sh)
#   DRAFT=1 scripts/release.sh            create it as a draft
#   DRY_RUN=1 scripts/release.sh          check everything, show the notes, upload nothing
#
# Images are built on a build host, not by CI: a build needs tens of GB and
# over an hour, more than a hosted runner gives. This script only uploads what
# the builders left in OUTPUT_DIR, and refuses anything it cannot vouch for:
# outputs of different commits, a build from uncommitted changes, a commit the
# remote does not have, or a tag that already exists.
#
# Needs gh, logged in with write access to the repository.

set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$REPO/local.conf" ] && . "$REPO/local.conf"
OUTPUT_DIR=${OUTPUT_DIR:-$REPO/output}

# What a release carries: the boards the images were tested on, as an update
# (sysupgrade) and as a fresh SD card. The builders make more (PoE and NAND
# variants, eMMC/NAND images for the install scripts); those stay out until
# they have been tried on real hardware.
RELEASE_DEVICES=${RELEASE_DEVICES:-"bpi-r4 bpi-r4-8gb bpi-r4-pro-8x"}
RELEASE_KINDS="squashfs-sysupgrade.itb sdcard.img.gz"

die() { echo "ERROR: $*" >&2; exit 1; }
field() { sed -n "s/^$2 *: *//p" "$1/MANIFEST.txt" | head -1; }

command -v gh >/dev/null || die "gh (GitHub CLI) is not installed"
gh auth status >/dev/null 2>&1 || die "gh is not logged in"

if [ $# -gt 0 ]; then
	outs=("$@")
else
	outs=()
	for b in bpi-r4 bpi-r4-pro-8x; do
		d=$(ls -d "$OUTPUT_DIR"/*-"$b" 2>/dev/null | sort | tail -1 || true)
		[ -n "$d" ] || die "no output for $b in $OUTPUT_DIR"
		outs+=("$d")
	done
fi

commit=""
for d in "${outs[@]}"; do
	[ -f "$d/MANIFEST.txt" ] || die "$d: no MANIFEST.txt - not a builder output"
	c=$(field "$d" repo)
	[ -n "$c" ] || die "$d: MANIFEST names no repository commit"
	[ -z "$commit" ] || [ "$c" = "$commit" ] ||
		die "outputs of different commits: ${commit:0:7} and ${c:0:7} - build both boards from one commit"
	commit=$c
	case "$(field "$d" dirty)" in
	no) ;;
	yes) die "$d was built from uncommitted changes - not publishable" ;;
	*) echo "WARNING: $d predates the dirty marker; its build refused uncommitted changes unless ALLOW_DIRTY=1 was set" >&2 ;;
	esac
	ls "$d"/images/*sysupgrade.itb >/dev/null 2>&1 || die "$d: no sysupgrade image"
done

cd "$REPO"
git fetch -q origin
[ -n "$(git branch -r --contains "$commit" 2>/dev/null)" ] ||
	die "commit ${commit:0:7} is not on the remote - push it first"

built=$(field "${outs[0]}" built)
tag="build-$(echo "$built" | cut -c1-10 | tr -d -)-${commit:0:7}"
gh release view "$tag" >/dev/null 2>&1 && die "release $tag already exists"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
boards=""
for d in "${outs[@]}"; do
	b=$(field "$d" board)
	boards="$boards $b"
	cp "$d/MANIFEST.txt" "$stage/MANIFEST-$b.txt"
	for dev in $RELEASE_DEVICES; do
		# each device from its own board's output only
		case "$b:$dev" in
		bpi-r4-pro-8x:bpi-r4-pro-8x) ;;
		bpi-r4-pro-8x:*|bpi-r4:bpi-r4-pro-8x) continue ;;
		esac
		for k in $RELEASE_KINDS; do
			f="$d/images/openwrt-mediatek-filogic-bananapi_$dev-$k"
			[ -f "$f" ] || continue
			[ -e "$stage/$(basename "$f")" ] && die "two outputs have an image named $(basename "$f")"
			ln -s "$f" "$stage/$(basename "$f")"
		done
	done
done
for dev in $RELEASE_DEVICES; do
	for k in $RELEASE_KINDS; do
		[ -e "$stage/openwrt-mediatek-filogic-bananapi_$dev-$k" ] ||
			die "no $dev $k in the outputs given"
	done
done
( cd "$stage" && sha256sum -- * > SHA256SUMS )

{
	echo "Images built from ${commit:0:7} on ${built}, for:${boards}."
	echo
	echo "| Board | Update a running box | Fresh install on an SD card |"
	echo "|---|---|---|"
	for d in "${outs[@]}"; do
		for dev in $RELEASE_DEVICES; do
			n="openwrt-mediatek-filogic-bananapi_$dev-squashfs-sysupgrade.itb"
			[ -L "$stage/$n" ] && [ "$(readlink "$stage/$n")" = "$d/images/$n" ] || continue
			echo "| $dev | \`$n\` | \`openwrt-mediatek-filogic-bananapi_$dev-sdcard.img.gz\` |"
		done
	done
	echo
	echo "Update with \`sysupgrade\` (keeps the configuration), or write the SD image to a card and boot from it."
	echo "Only boards tested on real hardware are here; the builders make more variants."
	echo "Every upstream revision the images were built from is listed in \`MANIFEST-<board>.txt\`;"
	echo "checksums in \`SHA256SUMS\`."
} > "$stage/NOTES.md"

echo "release $tag ->$boards, commit ${commit:0:7}, $(ls "$stage" | grep -vc NOTES.md) files, $(du -shL "$stage" | cut -f1)"
if [ "${DRY_RUN:-0}" = 1 ]; then
	cat "$stage/NOTES.md"; ls -lL "$stage" | grep -v NOTES.md
	echo "dry run - nothing published"; exit 0
fi
gh release create "$tag" --target "$commit" --title "Build $(echo "$built" | cut -c1-10) (${commit:0:7})" \
	--notes-file "$stage/NOTES.md" --prerelease ${DRAFT:+--draft} \
	$(cd "$stage" && ls | grep -v '^NOTES.md$' | sed "s|^|$stage/|")
echo "published: $(gh release view "$tag" --json url --jq .url)"
