#!/bin/sh
# install-nvme-pro8x.sh - install EasyMesh Wi-Fi 7 for OpenWrt to the NVMe disk of a BPI-R4 Pro 8X
# Must be run from the NAND rescue system: sh /root/install-dir/install-nvme.sh
#   (TAG=<release tag> sh ... for another release)
#
# Adapted from woziwrt/bpi-r4-deploy (see ../README.md): the images come from this repository's release
# and every download is checked against the release's SHA256SUMS. U-Boot looks for the kernel on p1 as
# bpi-r4-pro-8x.itb, so the downloaded sysupgrade image is stored under that name.

GH_USER="woziwrt"
GH_REPO="openwrt-easymesh-wifi7"
GH_TAG="${TAG:-lab-emmc-rc4}"
ITB_NAME="bpi-r4-pro-8x.itb"
DL_ITB_NAME="openwrt-mediatek-filogic-bananapi_bpi-r4-pro-8x-squashfs-sysupgrade.itb"
IMG_NAME="openwrt-mediatek-filogic-bananapi_bpi-r4-pro-8x-nvme-img.bin"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

printf "\n"
printf "=================================================\n"
printf "  BPI-R4 Pro 8X - Install OpenWrt to NVMe\n"
printf "=================================================\n"
printf "\n"

ITB="/tmp/${ITB_NAME}"
IMG="/tmp/${IMG_NAME}"

printf "  Release: %s/%s %s\n\n" "$GH_USER" "$GH_REPO" "$GH_TAG"

# || Pro: NVMe device detection ||||||||||||||||||||||||||||||||||||||||||||||

printf "[ Pro ] Detecting NVMe device...\n"

NVME_LIST=""
for DEV in /dev/nvme0n1 /dev/nvme1n1; do
    [ -b "$DEV" ] && NVME_LIST="${NVME_LIST} ${DEV}"
done

NVME_COUNT=$(echo "$NVME_LIST" | wc -w)

if [ "$NVME_COUNT" -eq 0 ]; then
    printf "\n${RED}ERROR: No NVMe disk found. Check PCIe connection and reboot.${NC}\n\n"
    exit 1
elif [ "$NVME_COUNT" -eq 1 ]; then
    NVME_DEV=$(echo "$NVME_LIST" | tr -d ' ')
    printf "        OK -- found %s\n\n" "$NVME_DEV"
else
    printf "\n  Multiple NVMe disks found. Select the target disk:\n\n"
    N=1
    for DEV in $NVME_LIST; do
        printf "  %d) %s\n" "$N" "$DEV"
        N=$((N + 1))
    done
    printf "\n  Enter choice: "
    read NVME_CHOICE
    NVME_DEV=$(echo "$NVME_LIST" | tr ' ' '\n' | sed -n "${NVME_CHOICE}p")
    if [ ! -b "$NVME_DEV" ]; then
        printf "\n${RED}ERROR: Invalid choice!${NC}\n\n"
        exit 1
    fi
    printf "        OK -- selected %s\n\n" "$NVME_DEV"
fi

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
printf "        OK -- %s (detected above)\n\n" "$NVME_DEV"

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
printf "  [2] Use local files from /tmp (testing)\n\n"
printf "  Select [1/2]: "
read USE_LOCAL

case "$USE_LOCAL" in
    2)
        printf "\n        INFO: Using local files from /tmp\n"
        ITB="/tmp/${ITB_NAME}"
        IMG="/tmp/${IMG_NAME}"
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
        ITB_URL="${REL_URL}/${DL_ITB_NAME}"

        printf "[ 5/7 ] Network check...\n\n"
        printf "        INFO: Internet required (~270 MB download)\n"
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
        if ! wget -q --spider "$ITB_URL" 2>/dev/null; then
            printf "\n${RED}ERROR: Release not found on GitHub (tag: %s).${NC}\n\n" "$GH_TAG"
            exit 1
        fi
        printf "        OK -- release available\n\n"

        if ! wget -O /tmp/SHA256SUMS "${REL_URL}/SHA256SUMS"; then
            printf "\n${RED}ERROR: Download of SHA256SUMS failed.${NC}\n\n"; exit 1
        fi
        # A half-downloaded or wrong image written to the flash is a box that does not boot.
        for F in "$DL_ITB_NAME" "${IMG_NAME}.gz"; do
            printf "        Downloading %s...\n" "$F"
            if ! wget -O "/tmp/$F" "${REL_URL}/$F" || [ ! -s "/tmp/$F" ]; then
                printf "\n${RED}ERROR: Download of %s failed.${NC}\n\n" "$F"
                rm -f "/tmp/$DL_ITB_NAME" "$IMG.gz"; exit 1
            fi
            WANT=$(grep " ${F}\$" /tmp/SHA256SUMS | cut -d' ' -f1)
            GOT=$(sha256sum "/tmp/$F" | cut -d' ' -f1)
            if [ -z "$WANT" ] || [ "$WANT" != "$GOT" ]; then
                printf "\n${RED}ERROR: %s does not match SHA256SUMS of the release.${NC}\n\n" "$F"
                rm -f "/tmp/$DL_ITB_NAME" "$IMG.gz"; exit 1
            fi
            printf "        OK -- %s downloaded, checksum matches\n\n" "$F"
        done
        mv "/tmp/$DL_ITB_NAME" "$ITB"
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

MOUNTED=$(mount | grep "^${NVME_DEV}" | awk '{print $1}')
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

printf "        Repartitioning (p1=256MB, p2=16GiB production, p3=data)...\n"
sgdisk -d 1 -d 2 "$NVME_DEV"
sgdisk -n 1:2048:526335     -t 1:8300 -c 1:boot       "$NVME_DEV"
sgdisk -n 2:526336:34080767 -t 2:FFFF -c 2:production "$NVME_DEV"
partprobe "$NVME_DEV"
sleep 2
printf "        OK\n\n"

printf "        Formatting boot partition (p1 ext4)...\n"
mkfs.ext4 -F "${NVME_DEV}p1"
printf "        OK\n\n"

printf "        Writing kernel to p1...\n"
mkdir -p /mnt/nvme
mount "${NVME_DEV}p1" /mnt/nvme
cp "$ITB" /mnt/nvme/"$ITB_NAME"
sync
umount "${NVME_DEV}p1"
printf "        OK -- kernel written to p1\n\n"

printf "        Writing rootfs to p2 (raw FIT)...\n"
dd if="$ITB" of="${NVME_DEV}p2" bs=1M conv=fsync
if [ $? -ne 0 ]; then
    printf "\n${RED}ERROR: dd rootfs failed.${NC}\n\n"; exit 1
fi
sync
printf "        OK -- rootfs written to p2\n\n"

printf "        Creating data partition (p3)...\n"
sgdisk -e "$NVME_DEV"
sgdisk -n 3:0:0 -t 3:8300 -c 3:data "$NVME_DEV"
partprobe "$NVME_DEV"
sleep 2
umount "${NVME_DEV}p3" 2>/dev/null || true
mkfs.ext4 -F -L data "${NVME_DEV}p3"
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
