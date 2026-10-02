#!/bin/sh
# install-nvme.sh - install EasyMesh Wi-Fi 7 for OpenWrt to the NVMe disk of a BPI-R4 (4 GB or 8 GB)
# Must be run from the NAND rescue system: the box keeps booting from NAND, whose U-Boot then loads the system
# from the NVMe (nvme_boot=1).
#
#   wget -O /tmp/install-nvme.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-nvme.sh
#   sh /tmp/install-nvme.sh            (TAG=<release tag> sh ... for another release)
#
# Adapted from woziwrt/bpi-r4-deploy (see ../README.md): the images come from this repository's release, the
# board is told by its memory, and every download is checked against the release's SHA256SUMS.

NVME_DEV="/dev/nvme0n1"
GH_USER="woziwrt"
GH_REPO="openwrt-easymesh-wifi7"
GH_TAG="${TAG:-lab-emmc-rc4}"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

printf "\n"
printf "=================================================\n"
printf "  BPI-R4 NVMe Installer\n"
printf "=================================================\n"
printf "\n"

# || 0. Board ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

# The 4 GB and 8 GB boards need different images and report the same model name, so tell them by memory.
RAM_GB=$(awk '/MemTotal/ { print int($2 / 1048576 + 0.5) }' /proc/meminfo)
case "$RAM_GB" in
    3|4) BOARD="BPI-R4 4 GB"; DEV_NAME="bananapi_bpi-r4" ;;
    7|8) BOARD="BPI-R4 8 GB"; DEV_NAME="bananapi_bpi-r4-8gb" ;;
    *)
        printf "\n${RED}ERROR: %s GB of memory - not a BPI-R4 4 GB or 8 GB.${NC}\n" "$RAM_GB"
        printf "       For a BPI-R4 Pro 8X use pro-8x/install-nvme-pro8x.sh.\n\n"
        exit 1
        ;;
esac
ITB_NAME="openwrt-mediatek-filogic-${DEV_NAME}-squashfs-sysupgrade.itb"
IMG_NAME="openwrt-mediatek-filogic-${DEV_NAME}-nvme-img.bin"
ITB="/tmp/${ITB_NAME}"
IMG="/tmp/${IMG_NAME}"

printf "  Board:   %s (%s GB of memory)\n" "$BOARD" "$RAM_GB"
printf "  Release: %s/%s %s\n" "$GH_USER" "$GH_REPO" "$GH_TAG"
printf "  Is that right? [yes/no]: "
read BOARD_OK
if [ "$BOARD_OK" != "yes" ]; then
    printf "\n  Cancelled.\n\n"
    exit 1
fi

printf "\n"

# || 1. Check boot media |||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 1/7 ] Checking boot media...\n"

if ! grep -q "ubi" /proc/cmdline; then
    printf "\n${RED}ERROR: Must be run from NAND rescue system!${NC}\n"
    printf "       Current boot is not from NAND/UBI.\n\n"
    exit 1
fi

printf "        OK -- running from NAND rescue\n\n"

# || 2. NVMe device check ||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 2/7 ] Checking NVMe device...\n"

if [ ! -b "$NVME_DEV" ]; then
    printf "\n${RED}ERROR: NVMe disk not found (%s does not exist).${NC}\n" "$NVME_DEV"
    printf "       Check physical connection and reboot.\n\n"
    exit 1
fi

printf "        OK -- found %s\n\n" "$NVME_DEV"

# || 3. SMART health check ||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 3/7 ] Checking disk health (SMART)...\n\n"

SMART_OUT=$(smartctl -a "$NVME_DEV" 2>/dev/null)

if [ -z "$SMART_OUT" ]; then
    printf "${YELLOW}WARNING: Could not read SMART data -- smartctl failed.${NC}\n"
    printf "         Skipping disk health check.\n\n"
    SMART_SKIP=1
fi

if [ -z "$SMART_SKIP" ]; then
    FAIL=0
    WARN=0

    MODEL=$(echo "$SMART_OUT"    | grep "Model Number"       | sed 's/.*: *//')
    SERIAL=$(echo "$SMART_OUT"   | grep "Serial Number"      | sed 's/.*: *//')
    CAPACITY=$(echo "$SMART_OUT" | grep "Total NVM Capacity" | sed 's/.*: *//')
    printf "        Disk    : %s\n" "$MODEL"
    printf "        Serial  : %s\n" "$SERIAL"
    printf "        Capacity: %s\n\n" "$CAPACITY"

    HEALTH=$(echo "$SMART_OUT" | grep "SMART overall-health" | grep -o "PASSED\|FAILED")
    if [ "$HEALTH" = "FAILED" ]; then
        printf "${RED}  [FAIL] SMART overall-health: FAILED${NC}\n"; FAIL=1
    else
        printf "${GREEN}  [ OK ] SMART overall-health: PASSED${NC}\n"
    fi

    CRIT=$(echo "$SMART_OUT" | grep "Critical Warning" | awk '{print $NF}')
    if [ "$CRIT" != "0x00" ] && [ -n "$CRIT" ]; then
        printf "${RED}  [FAIL] Critical Warning: %s${NC}\n" "$CRIT"; FAIL=1
    else
        printf "${GREEN}  [ OK ] Critical Warning: %s${NC}\n" "$CRIT"
    fi

    SPARE=$(echo "$SMART_OUT" | grep "Available Spare:" | grep -v Threshold | awk '{print $NF}' | tr -d '%')
    if [ -n "$SPARE" ] && [ "$SPARE" -lt 10 ]; then
        printf "${RED}  [FAIL] Available Spare: %s%%${NC}\n" "$SPARE"; FAIL=1
    else
        printf "${GREEN}  [ OK ] Available Spare: %s%%${NC}\n" "$SPARE"
    fi

    USED=$(echo "$SMART_OUT" | grep "Percentage Used" | awk '{print $NF}' | tr -d '%')
    if [ -n "$USED" ] && [ "$USED" -ge 100 ]; then
        printf "${RED}  [FAIL] Percentage Used: %s%%${NC}\n" "$USED"; FAIL=1
    else
        printf "${GREEN}  [ OK ] Percentage Used: %s%%${NC}\n" "$USED"
    fi

    MEDIA_ERR=$(echo "$SMART_OUT" | grep "Media and Data Integrity Errors" | awk '{print $NF}')
    if [ -n "$MEDIA_ERR" ] && [ "$MEDIA_ERR" -gt 0 ]; then
        printf "${YELLOW}  [WARN] Media and Data Integrity Errors: %s${NC}\n" "$MEDIA_ERR"; WARN=1
    else
        printf "${GREEN}  [ OK ] Media and Data Integrity Errors: %s${NC}\n" "$MEDIA_ERR"
    fi

    TEMP=$(echo "$SMART_OUT" | grep "^Temperature:" | awk '{print $2}')
    if [ -n "$TEMP" ] && [ "$TEMP" -ge 70 ]; then
        printf "${YELLOW}  [WARN] Disk temperature: %s C${NC}\n" "$TEMP"; WARN=1
    else
        printf "${GREEN}  [ OK ] Disk temperature: %s C${NC}\n" "$TEMP"
    fi

    printf "\n"

    if [ "$FAIL" -eq 1 ]; then
        printf "${RED}=================================================\n"
        printf "  Disk is not suitable for installation.\n"
        printf "=================================================${NC}\n\n"
        exit 1
    fi

    if [ "$WARN" -eq 1 ]; then
        printf "${YELLOW}  Disk has warnings. Continue anyway? [y/N] ${NC}"
        read ANSWER
        case "$ANSWER" in
            y|Y) printf "\n" ;;
            *)   printf "  Installation cancelled.\n\n"; exit 1 ;;
        esac
    else
        printf "${GREEN}  Disk is healthy. Proceeding.${NC}\n\n"
    fi
fi

# || 4. File source ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 4/7 ] File source...\n\n"
printf "  [1] Download from GitHub (default)\n"
printf "  [2] Use local files from /tmp (development/testing)\n\n"
printf "  Select [1/2]: "
read USE_LOCAL

case "$USE_LOCAL" in
    2)
        printf "\n        INFO: Using local files from /tmp\n"
        printf "        Checking files...\n"
        if [ ! -f "$ITB" ]; then
            printf "${RED}ERROR: %s not found!${NC}\n" "$ITB"; exit 1
        fi
        if [ ! -f "$IMG" ]; then
            printf "${RED}ERROR: %s not found!${NC}\n" "$IMG"; exit 1
        fi
        printf "        OK -- both files present\n\n"
        ;;
    *)
        REL_URL="${REL_URL:-https://github.com/${GH_USER}/${GH_REPO}/releases/download/${GH_TAG}}"
        ITB_URL="${REL_URL}/${ITB_NAME}"
        IMG_URL="${REL_URL}/${IMG_NAME}.gz"

        printf "        URL: %s\n\n" "$REL_URL"

        printf "[ 5/7 ] Network check...\n\n"
        printf "        INFO: Internet required (~270 MB download)\n"
        printf "        Is ethernet connected? [yes/no]: "
        read NET_CONFIRM

        if [ "$NET_CONFIRM" != "yes" ]; then
            printf "\n        Connect ethernet and run the script again.\n\n"
            exit 0
        fi

        if ! ping -c 1 -W 3 "$(echo "$REL_URL" | cut -d/ -f3 | cut -d: -f1)" > /dev/null 2>&1; then
            printf "\n${RED}ERROR: No network connectivity -- check ethernet and try again.${NC}\n\n"
            exit 1
        fi
        printf "        OK -- network available\n\n"

        printf "        Checking release availability...\n"
        HTTP_CODE=$(wget --server-response --spider "$IMG_URL" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}')
        if [ "$HTTP_CODE" != "200" ]; then
            printf "\n${RED}ERROR: Release not found on GitHub (tag: %s).\n" "$GH_TAG"
            printf "       Check the tag: https://github.com/${GH_USER}/${GH_REPO}/releases\n\n${NC}"
            exit 1
        fi
        printf "        OK -- release available\n\n"

        if ! wget -O /tmp/SHA256SUMS "${REL_URL}/SHA256SUMS"; then
            printf "\n${RED}ERROR: Download of SHA256SUMS failed.${NC}\n\n"; exit 1
        fi

        # A half-downloaded or wrong image written to the disk is a box that does not boot.
        for F in "$ITB_NAME" "$IMG_NAME.gz"; do
            printf "        Downloading %s...\n" "$F"
            if ! wget -O "/tmp/$F" "${REL_URL}/$F" || [ ! -s "/tmp/$F" ]; then
                printf "\n${RED}ERROR: Download of %s failed.${NC}\n\n" "$F"
                rm -f "$ITB" "$IMG.gz"; exit 1
            fi
            WANT=$(grep " ${F}\$" /tmp/SHA256SUMS | cut -d' ' -f1)
            GOT=$(sha256sum "/tmp/$F" | cut -d' ' -f1)
            if [ -z "$WANT" ] || [ "$WANT" != "$GOT" ]; then
                printf "\n${RED}ERROR: %s does not match SHA256SUMS of the release.${NC}\n\n" "$F"
                rm -f "$ITB" "$IMG.gz"; exit 1
            fi
            printf "        OK -- %s downloaded, checksum matches\n\n" "$F"
        done
        gunzip -f "$IMG.gz" || { printf "\n${RED}ERROR: Could not unpack the image.${NC}\n\n"; exit 1; }
        ;;
esac

# || 6. Write image |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 6/7 ] Writing image...\n\n"
printf "${RED}  WARNING: This will ERASE ALL DATA on %s.${NC}\n\n" "$NVME_DEV"
printf "  Are you sure? Type YES to confirm: "
read CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    printf "\n  Installation cancelled.\n\n"
    rm -f "$ITB" "$IMG"
    exit 1
fi

printf "\n"

MOUNTED=$(mount | grep "^/dev/nvme0" | awk '{print $1}')
if [ -n "$MOUNTED" ]; then
    for DEV in $MOUNTED; do
        umount "$DEV" 2>/dev/null || true
    done
fi

printf "        Wiping disk (stale GPT + fs signatures)...\n"
sgdisk --zap-all "$NVME_DEV" 2>/dev/null || true
wipefs -a "$NVME_DEV" 2>/dev/null || true
dd if=/dev/zero of="$NVME_DEV" bs=1M count=100 conv=fsync
sync
printf "        OK -- disk wiped\n\n"
printf "        Writing partition layout (nvme-img.bin)...\n"
dd if="$IMG" of="$NVME_DEV" bs=1M conv=fsync
if [ $? -ne 0 ]; then
    printf "\n${RED}ERROR: dd nvme-img.bin failed.${NC}\n\n"; exit 1
fi
sync
partprobe "$NVME_DEV" 2>/dev/null
sleep 2
printf "        OK\n\n"

# p2 (production) = 16 GiB (raw FIT + f2fs overlay = system root); the bulk of
# the disk goes to p3 (data, ext4, LABEL=data) as an upgrade-safe store. 16GiB
# is generous for a router+docker root yet a tiny fraction of an NVMe. The f2fs
# overlay is formatted on first boot to fill p2. [16GiB = 33554432 sectors]
printf "        Repartitioning (p1=256MB, p2=16GiB, p3=data)...\n"
sgdisk -d 1 -d 2 /dev/nvme0n1
sgdisk -n 1:2048:526335     -t 1:8300 -c 1:boot       /dev/nvme0n1
sgdisk -n 2:526336:34080767 -t 2:FFFF -c 2:production /dev/nvme0n1
partprobe /dev/nvme0n1
sleep 2
printf "        OK\n\n"

printf "        Formatting boot partition (p1 ext4)...\n"
mkfs.ext4 -F /dev/nvme0n1p1
printf "        OK\n\n"

printf "        Writing kernel to p1...\n"
mkdir -p /mnt/nvme
mount /dev/nvme0n1p1 /mnt/nvme
cp "$ITB" /mnt/nvme/bpi-r4.itb
sync
umount /dev/nvme0n1p1
printf "        OK -- kernel written to p1\n\n"

printf "        Writing rootfs to p2 (raw FIT)...\n"
dd if="$ITB" of=/dev/nvme0n1p2 bs=1M conv=fsync
if [ $? -ne 0 ]; then
    printf "\n${RED}ERROR: dd rootfs failed.${NC}\n\n"; exit 1
fi
sync
printf "        OK -- rootfs written to p2\n\n"

printf "        Creating data partition (p3)...\n"
sgdisk -e /dev/nvme0n1
sgdisk -n 3:0:0 -t 3:8300 -c 3:data /dev/nvme0n1
partprobe /dev/nvme0n1
sleep 2
umount /dev/nvme0n1p3 2>/dev/null || true
mkfs.ext4 -F -L data /dev/nvme0n1p3
printf "        OK -- p3 data partition created\n\n"

rm -f "$ITB" "$IMG"

# || 7. Finalize |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

printf "[ 7/7 ] Finalizing...\n\n"

printf "        Setting U-Boot env for NVMe boot...\n"
fw_setenv nvme_boot 1
if [ $? -ne 0 ]; then
    printf "${YELLOW}WARNING: fw_setenv failed -- set nvme_boot manually${NC}\n"
else
    printf "        OK -- nvme_boot=1 set\n"
fi
printf "\n"

printf "${GREEN}=================================================\n"
printf "  Installation complete! Rebooting...\n"
printf "=================================================${NC}\n\n"
sleep 2
reboot
