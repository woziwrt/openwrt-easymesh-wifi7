#!/bin/sh
# install-emmc-pro8x.sh - install EasyMesh Wi-Fi 7 for OpenWrt to the eMMC of a BPI-R4 Pro 8X
# Must be run from the NAND rescue system only: SD and eMMC share one controller.
#
#   sh /root/install-dir/install-emmc.sh   (TAG=<release tag> sh ... for another release)
#
# Adapted from woziwrt/bpi-r4-deploy (see ../README.md): one image, from this repository's release,
# checked against the release's SHA256SUMS before anything is written.

EMMC_DEV="/dev/mmcblk0"
EMMC_BOOT="/dev/mmcblk0boot0"
GH_USER="${GH_USER_OVERRIDE:-woziwrt}"
GH_REPO="openwrt-easymesh-wifi7"
GH_TAG="${TAG:-lab-emmc-rc4}"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

printf "\n"
printf "=================================================\n"
printf "  BPI-R4 Pro 8X - Install OpenWrt to eMMC\n"
printf "=================================================\n"
printf "\n"

# || 0. Board ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

if ! grep -q "bpi-r4-pro-8x" /tmp/sysinfo/board_name 2>/dev/null; then
    printf "\n${RED}ERROR: this is not a BPI-R4 Pro 8X (%s).${NC}\n" "$(cat /tmp/sysinfo/board_name 2>/dev/null)"
    printf "       For a BPI-R4 use r4/install-emmc.sh.\n\n"
    exit 1
fi
EMMC_NAME="openwrt-mediatek-filogic-bananapi_bpi-r4-pro-8x-emmc-img.bin"

EMMC_IMG="/tmp/${EMMC_NAME}"

printf "  Release: %s/%s %s\n\n" "$GH_USER" "$GH_REPO" "$GH_TAG"

# || 1. Check boot media |||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 1/7 ] Checking boot media...\n"

if ! grep -q "ubi" /proc/cmdline; then
    printf "\n${RED}ERROR: Must be run from NAND rescue system!${NC}\n"
    printf "       Current boot is not from NAND/UBI.\n\n"
    exit 1
fi

printf "        OK -- running from NAND rescue\n\n"

# || 2. Check eMMC device ||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 2/7 ] Checking eMMC device...\n"

if [ ! -b "$EMMC_DEV" ]; then
    printf "\n${RED}ERROR: eMMC not found (%s does not exist).${NC}\n" "$EMMC_DEV"
    printf "       Check hardware and reboot.\n\n"
    exit 1
fi

if [ ! -b "$EMMC_BOOT" ]; then
    printf "\n${RED}ERROR: %s not found -- this may be SD card, not eMMC!${NC}\n" "$EMMC_BOOT"
    printf "       Make sure eMMC is installed and detected.\n\n"
    exit 1
fi

printf "        OK -- found %s\n\n" "$EMMC_DEV"

# || 3. File source ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 3/7 ] File source...\n\n"
printf "  [1] Download from GitHub (default)\n"
printf "  [2] Use local files from /tmp (testing)\n\n"
printf "  Select [1/2]: "
read USE_LOCAL

case "$USE_LOCAL" in
    2)
        printf "\n        INFO: Using local files from /tmp\n"
        if [ ! -f "$EMMC_IMG" ]; then
            printf "${RED}ERROR: %s not found!${NC}\n" "$EMMC_IMG"
            exit 1
        fi
        printf "        OK -- file present\n\n"
        ;;
    *)
        REL_URL="${REL_URL:-https://github.com/${GH_USER}/${GH_REPO}/releases/download/${GH_TAG}}"
        EMMC_IMG_URL="${REL_URL}/${EMMC_NAME}.gz"

        # || 4. Network check ||||||||||||||||||||||||||||||||||||||||||||||||

        printf "[ 4/7 ] Network check...\n\n"
        printf "        INFO: Internet required (~154 MB download)\n"
        printf "        Is WAN cable connected? [yes/no]: "
        read NET_CONFIRM

        if [ "$NET_CONFIRM" != "yes" ]; then
            printf "\n        Connect WAN cable and run the script again.\n\n"
            exit 0
        fi

        if ! ping -c 1 -W 3 "$(echo "$REL_URL" | cut -d/ -f3 | cut -d: -f1)" > /dev/null 2>&1; then
            printf "\n${RED}ERROR: No network connectivity -- check WAN cable and try again.${NC}\n\n"
            exit 1
        fi
        printf "        OK -- network available\n\n"

        printf "        Checking release availability...\n"
        # The exit code, not a header: a "Server:" header containing "HTTP/" was
        # taken for the status line (2026-10-02, a test mirror).
        if ! wget -q --spider "$EMMC_IMG_URL" 2>/dev/null; then
            printf "\n${RED}ERROR: Release not found on GitHub (tag: %s).${NC}\n\n" "$GH_TAG"
            exit 1
        fi
        printf "        OK -- release available\n\n"

        # || 5. Download ||||||||||||||||||||||||||||||||||||||||||||||||||||

        printf "[ 5/7 ] Downloading %s...\n\n" "$EMMC_NAME"

        wget -O "$EMMC_IMG.gz" "$EMMC_IMG_URL" && wget -O /tmp/SHA256SUMS "${REL_URL}/SHA256SUMS"
        if [ $? -ne 0 ] || [ ! -s "$EMMC_IMG.gz" ]; then
            printf "\n${RED}ERROR: Download failed.${NC}\n\n"
            rm -f "$EMMC_IMG.gz"
            exit 1
        fi
        # A half-downloaded or wrong image written to the eMMC is a box that does not boot.
        WANT=$(grep " ${EMMC_NAME}.gz\$" /tmp/SHA256SUMS | cut -d' ' -f1)
        GOT=$(sha256sum "$EMMC_IMG.gz" | cut -d' ' -f1)
        if [ -z "$WANT" ] || [ "$WANT" != "$GOT" ]; then
            printf "\n${RED}ERROR: Checksum does not match SHA256SUMS of the release.${NC}\n\n"
            rm -f "$EMMC_IMG.gz"
            exit 1
        fi
        gunzip -f "$EMMC_IMG.gz" || { printf "\n${RED}ERROR: Could not unpack the image.${NC}\n\n"; exit 1; }
        printf "\n        OK -- downloaded, checksum matches, unpacked\n\n"
        ;;
esac

# || 6. Confirm and write ||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 6/7 ] Writing image...\n\n"
printf "${RED}  WARNING: This will ERASE ALL DATA on %s.${NC}\n\n" "$EMMC_DEV"
printf "  Are you sure? Type YES to confirm: "
read CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    printf "\n  Installation cancelled.\n\n"
    rm -f "$EMMC_IMG"
    exit 1
fi

printf "\n"
printf "        Wiping disk (stale GPT + fs signatures)...\n"
sgdisk --zap-all "$EMMC_DEV" 2>/dev/null || true
wipefs -a "$EMMC_DEV" 2>/dev/null || true
dd if=/dev/zero of="$EMMC_DEV" bs=1M count=100 conv=fsync
sync
printf "        OK -- disk wiped\n\n"
printf "        Writing image to %s...\n" "$EMMC_DEV"
dd if="$EMMC_IMG" of="$EMMC_DEV" bs=1M conv=fsync
if [ $? -ne 0 ]; then
    printf "\n${RED}ERROR: dd failed.${NC}\n\n"
    rm -f "$EMMC_IMG"
    exit 1
fi
sync
printf "        OK -- image written\n\n"

# Expand 'production' to fill the whole eMMC so the f2fs overlay (rootfs_data)
# uses the full disk. The dd image is small, so the backup GPT sits at the image
# end and the GPT thinks the disk ends early -> sgdisk -e relocates the backup
# GPT to the REAL disk end first, then resizepart grows production. Size is read
# from sysfs, so this adapts to any eMMC size.
printf "        Expanding production to fill eMMC...\n"
sgdisk -e "$EMMC_DEV" >/dev/null 2>&1
DISK_SECTORS=$(cat /sys/class/block/$(basename "$EMMC_DEV")/size)
printf "        Real eMMC size: %s sectors (~%s GiB)\n" "$DISK_SECTORS" "$((DISK_SECTORS/2097152))"
PNUM=$(sgdisk -p "$EMMC_DEV" 2>/dev/null | awk '$NF=="production"{print $1}')
parted -s "$EMMC_DEV" resizepart "$PNUM" 100%
partprobe "$EMMC_DEV" 2>/dev/null
printf "        OK -- production fills eMMC (f2fs overlay fills on first boot)\n\n"

printf "        Writing BL2 to boot partition...\n"
echo 0 > /sys/block/mmcblk0boot0/force_ro
dd if="$EMMC_IMG" of="$EMMC_BOOT" bs=512 skip=34 count=512 conv=fsync
sync
printf "        OK -- BL2 written\n\n"

# || 7. Finalize |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 7/7 ] Finalizing...\n"

mmc bootpart enable 1 1 "$EMMC_DEV"
printf "        OK -- eMMC boot partition set\n"

rm -f "$EMMC_IMG"
printf "        OK -- cleanup done\n\n"

printf "${GREEN}=================================================\n"
printf "  Installation complete!\n"
printf "=================================================${NC}\n\n"
printf "Next steps:\n"
printf "  1. Power off the device\n"
printf "  2. Set DIP switches: A=1, B=0 (eMMC boot)\n"
printf "  3. Power on\n"
printf "  4. Login via SSH or LuCI (http://192.168.1.1) and run:\n"
printf "     sh /root/install-dir/install-nvme.sh\n"
printf "\n"
