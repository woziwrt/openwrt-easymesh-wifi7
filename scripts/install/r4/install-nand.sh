#!/bin/sh
# install-nand.sh - write the lean NAND installer system to the SPI-NAND of a BPI-R4 (4 GB or 8 GB)
# Run from the SD card. The NAND system is what installs the eMMC/NVMe: SD and eMMC share one controller,
# so the eMMC can only be written while the box runs from NAND.
#
#   sh /root/install-dir/install-nand.sh   (TAG=<release tag> sh ... for another release)
#
# Adapted from woziwrt/bpi-r4-deploy (see ../README.md): the image comes from this repository's release,
# the board is told by its memory, and the download is checked against the release's SHA256SUMS.

GH_USER="woziwrt"
GH_REPO="openwrt-easymesh-wifi7"
GH_TAG="${TAG:-lab-emmc-rc4}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

printf "\n"
printf "=================================================\n"
printf "  BPI-R4 NAND Installer\n"
printf "=================================================\n"
printf "\n"

# || 0. Board ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
# The NAND image only differs by memory (DRAM training in BL2), and the 4 GB and 8 GB boards report the
# same model name, so tell them by memory.
RAM_GB=$(awk '/MemTotal/ { print int($2 / 1048576 + 0.5) }' /proc/meminfo)
case "$RAM_GB" in
    3|4) RAM_DEF=1 ;;
    7|8) RAM_DEF=2 ;;
    *)   RAM_DEF="" ;;
esac
printf "Select your board:\n\n"
printf "  [1] BPI-R4 4 GB\n"
printf "  [2] BPI-R4 8 GB\n\n"
printf "  (this box has %s GB of memory; for a BPI-R4 Pro 8X use the pro-8x scripts)\n\n" "$RAM_GB"
printf "  Enter choice [1/2]%s: " "${RAM_DEF:+ (Enter = $RAM_DEF)}"
read RAM_CHOICE
[ -z "$RAM_CHOICE" ] && RAM_CHOICE="$RAM_DEF"
case "$RAM_CHOICE" in
    1) RAM_LABEL="4GB"; DEV_NAME="bananapi_bpi-r4"; NAND_DEV="bananapi_bpi-r4-nand" ;;
    2) RAM_LABEL="8GB"; DEV_NAME="bananapi_bpi-r4-8gb"; NAND_DEV="bananapi_bpi-r4-nand-8gb" ;;
    *)
        printf "\n${RED}ERROR: Invalid choice.${NC}\n\n"
        exit 1
        ;;
esac
# The 4 GB and 8 GB images differ in the DRAM setup: the wrong one does not boot. Allowed (an image for
# another box), but only on purpose.
if [ "$RAM_CHOICE" != "$RAM_DEF" ]; then
    printf "\n${YELLOW}  This box has %s GB of memory, but the %s image was chosen.${NC}\n" "$RAM_GB" "$RAM_LABEL"
    printf "  Continue anyway? [yes/no]: "
    read RAM_OK
    [ "$RAM_OK" = "yes" ] || { printf "\n  Cancelled.\n\n"; exit 1; }
fi
BOARD="BPI-R4 $RAM_LABEL"
SNAND_NAME="openwrt-mediatek-filogic-${NAND_DEV}-snand-img.bin"
SNAND_IMG="/tmp/${SNAND_NAME}"
SOURCE_IS_LOCAL=0

printf "\n  Board:   %s\n" "$BOARD"
printf "  Release: %s/%s %s\n" "$GH_USER" "$GH_REPO" "$GH_TAG"
printf "\n"

# || 1. Check boot media ||||||||||||||||||||||||||||||||||||||||||||||||||||||
# Must NOT be booted from NAND itself (can't rewrite the running NAND).

printf "[ 1/6 ] Checking boot media...\n"

if grep -q "ubi" /proc/cmdline 2>/dev/null; then
    printf "\n"
    printf "${RED}ERROR: You are booted from NAND -- cannot overwrite the running NAND.${NC}\n"
    printf "       Boot from the SD card (DIP = SD) and run this again.\n"
    printf "\n"
    exit 1
fi

printf "        OK -- not running from NAND\n"
printf "\n"

# || 2. Check NAND device ||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 2/6 ] Checking NAND device...\n"

if ! grep -q "spi0.0" /proc/mtd 2>/dev/null; then
    printf "\n"
    printf "${RED}ERROR: NAND device (spi0.0) not found in /proc/mtd!${NC}\n"
    printf "\n"
    exit 1
fi

printf "        OK -- NAND device (spi0.0) found\n"
printf "\n"

# || 3. File source ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 3/6 ] File source...\n"
printf "\n"
printf "  [1] Download from GitHub (default)\n"
printf "  [2] Use local file from /tmp (development/testing)\n"
printf "\n"
printf "  Select [1/2]: "
read USE_LOCAL

case "$USE_LOCAL" in
    2)
        SOURCE_IS_LOCAL=1
        printf "\n"
        printf "        INFO: Using local file from /tmp\n"
        printf "        Expecting: %s\n" "$SNAND_IMG"
        if [ ! -f "$SNAND_IMG" ]; then
            printf "${RED}ERROR: %s not found!${NC}\n" "$SNAND_IMG"
            printf "       Copy the NAND image there first, e.g.:\n"
            printf "       scp %s root@<router>:/tmp/\n\n" "$SNAND_NAME"
            exit 1
        fi
        printf "        OK -- file present (%s)\n\n" "$(du -h "$SNAND_IMG" | cut -f1)"
        ;;
    *)
        REL_URL="${REL_URL:-https://github.com/${GH_USER}/${GH_REPO}/releases/download/${GH_TAG}}"
        SNAND_URL="${REL_URL}/${SNAND_NAME}.gz"
        printf "\n        URL: %s\n\n" "$SNAND_URL"

        # || 4. Network check ||||||||||||||||||||||||||||||||||||||||||||||||
        printf "[ 4/6 ] Network check...\n"
        printf "\n"
        printf "        INFO: Internet required (~40 MB download)\n"
        printf "        Is ethernet connected? [yes/no]: "
        read NET_CONFIRM

        if [ "$NET_CONFIRM" != "yes" ]; then
            printf "\n        Connect ethernet and run the script again.\n\n"
            exit 0
        fi

        if ! ping -c 1 -W 3 "$(echo "$REL_URL" | cut -d/ -f3 | cut -d: -f1)" > /dev/null 2>&1; then
            printf "\n"
            printf "${RED}ERROR: No network connectivity -- check ethernet and try again.${NC}\n"
            printf "\n"
            exit 1
        fi

        printf "        OK -- network available\n\n"

        printf "        Checking release availability...\n"
        # The exit code, not a header: a "Server:" header containing "HTTP/" was
        # taken for the status line (2026-10-02, a test mirror).
        if ! wget -q --spider "$SNAND_URL" 2>/dev/null; then
            printf "\n${RED}ERROR: Release not found on GitHub (tag: %s).\n" "$GH_TAG"
            printf "       Check the tag: https://github.com/${GH_USER}/${GH_REPO}/releases\n\n${NC}"
            exit 1
        fi
        printf "        OK -- release available\n\n"

        # || 5. Download snand-img.bin |||||||||||||||||||||||||||||||||||||||
        printf "[ 5/6 ] Downloading %s...\n\n" "$SNAND_NAME"

        if ! wget -O /tmp/SHA256SUMS "${REL_URL}/SHA256SUMS"; then
            printf "\n${RED}ERROR: Download of SHA256SUMS failed.${NC}\n\n"; exit 1
        fi
        # A half-downloaded or wrong image written to the flash is a box that does not boot.
        for F in "${SNAND_NAME}.gz"; do
            printf "        Downloading %s...\n" "$F"
            if ! wget -O "/tmp/$F" "${REL_URL}/$F" || [ ! -s "/tmp/$F" ]; then
                printf "\n${RED}ERROR: Download of %s failed.${NC}\n\n" "$F"
                rm -f "$SNAND_IMG.gz"; exit 1
            fi
            WANT=$(grep " ${F}\$" /tmp/SHA256SUMS | cut -d' ' -f1)
            GOT=$(sha256sum "/tmp/$F" | cut -d' ' -f1)
            if [ -z "$WANT" ] || [ "$WANT" != "$GOT" ]; then
                printf "\n${RED}ERROR: %s does not match SHA256SUMS of the release.${NC}\n\n" "$F"
                rm -f "$SNAND_IMG.gz"; exit 1
            fi
            printf "        OK -- %s downloaded, checksum matches\n\n" "$F"
        done
        gunzip -f "$SNAND_IMG.gz" || { printf "\n${RED}ERROR: Could not unpack the image.${NC}\n\n"; exit 1; }
        printf "        OK -- unpacked (%s)\n\n" "$(du -h "$SNAND_IMG" | cut -f1)"
        ;;
esac

# || 6. Confirm and write ||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 6/6 ] Writing image to NAND...\n"
printf "\n"
printf "${RED}  WARNING: This will ERASE the entire NAND (spi0.0).${NC}\n"
printf "\n"
printf "  Are you sure? Type YES to confirm: "
read CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    printf "\n  Installation cancelled.\n\n"
    [ "$SOURCE_IS_LOCAL" = "0" ] && rm -f "$SNAND_IMG"
    exit 1
fi

printf "\n"
printf "        Writing %s image to NAND...\n" "$RAM_LABEL"
mtd -e spi0.0 write "$SNAND_IMG" spi0.0
if [ $? -ne 0 ]; then
    printf "\n${RED}ERROR: mtd write failed.${NC}\n\n"
    [ "$SOURCE_IS_LOCAL" = "0" ] && rm -f "$SNAND_IMG"
    exit 1
fi
sync
printf "        OK -- image written to NAND\n\n"

# Keep local test files; only clean up downloaded ones.
if [ "$SOURCE_IS_LOCAL" = "0" ]; then
    rm -f "$SNAND_IMG"
    printf "        OK -- cleanup done\n"
else
    printf "        INFO: kept local file %s\n" "$SNAND_IMG"
fi
printf "\n"

printf "${GREEN}=================================================${NC}\n"
printf "${GREEN}  NAND installation complete!${NC}\n"
printf "${GREEN}=================================================${NC}\n"
printf "\n"
printf "  Next steps:\n"
printf "  1. Power off the device\n"
printf "  2. Set DIP switch to NAND boot (SW3-A=0, SW3-B=1)\n"
printf "  3. Power on\n"
printf "  4. Login via SSH and install eMMC/NVMe:\n"
printf "     /root/install-dir/install-nvme.sh\n"
printf "     /root/install-dir/install-emmc.sh\n"
printf "\n"
