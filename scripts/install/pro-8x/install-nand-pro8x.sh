#!/bin/sh
# install-nand-pro8x.sh - write the NAND system to the SPI-NAND of a BPI-R4 Pro 8X
# Run from the SD card: sh /root/install-dir/install-nand.sh   (TAG=<release tag> sh ... for another release)
# The Pro 8X has a 256 MiB NAND, so its NAND system is the full image.
#
# Image source is chosen interactively:
#   [1] Download from GitHub (default)  -- needs WAN/internet
#   [2] Use local file from /tmp        -- offline, for development/testing
# An explicit path argument overrides the menu (e.g. install-nand.sh /tmp/x.bin).
#
# Adapted from woziwrt/bpi-r4-deploy (see ../README.md): the image comes from this repository's release
# and the download is checked against the release's SHA256SUMS.

set -e

GH_USER="woziwrt"
GH_REPO="openwrt-easymesh-wifi7"
GH_TAG="${TAG:-lab-emmc-rc4}"
SNAND_NAME="openwrt-mediatek-filogic-bananapi_bpi-r4-pro-8x-snand-img.bin"

echo ""
echo "=================================================="
echo "  BPI-R4 Pro 8X - Install OpenWrt to NAND"
echo "=================================================="
echo ""

# || Image source: explicit arg -> source menu |||||||||||||||||
if [ -n "${1:-}" ]; then
    NAND_IMG="$1"
    echo "OK: Using image passed as argument: ${NAND_IMG}"
else
    echo "  Release: ${GH_USER}/${GH_REPO} ${GH_TAG}"
    echo ""

    # -- image source --------------------------------------------------------
    echo "  Select image source:"
    echo ""
    echo "    [1] Download from GitHub (default)"
    echo "    [2] Use local file from /tmp (development/testing)"
    echo ""
    printf "  Select [1/2]: "
    read SRC
    echo ""

    case "$SRC" in
        2)
            NAND_IMG="/tmp/${SNAND_NAME}"
            echo "INFO: Using local file ${NAND_IMG}"
            if [ ! -f "${NAND_IMG}" ]; then
                echo "ERROR: ${NAND_IMG} not found!"
                echo "       Copy it there first, e.g.:"
                echo "       scp ${SNAND_NAME} root@<router>:/tmp/"
                exit 1
            fi
            echo "OK: Local image found ($(du -h ${NAND_IMG} | cut -f1))."
            ;;
        *)
            echo "  IMPORTANT: Internet connection (WAN) is required to download."
            echo ""
            printf "  Is the WAN cable connected? [y/N]: "
            read ANS
            case "$ANS" in
                y|Y) ;;
                *) echo "  Connect WAN cable and run this script again."; echo ""; exit 1 ;;
            esac
            echo ""
            echo "Checking internet connection..."
            if ! wget -q --spider --timeout=10 "$REL_URL/SHA256SUMS" 2>/dev/null; then
                echo ""
                echo "ERROR: No internet connection!"
                echo "       Check WAN cable and router/modem, then try again."
                echo ""
                exit 1
            fi
            echo "OK: Internet connection available."
            echo ""
            REL_URL="${REL_URL:-https://github.com/${GH_USER}/${GH_REPO}/releases/download/${GH_TAG}}"
            echo "Downloading ${SNAND_NAME}.gz (${GH_TAG})..."
            if ! wget -O /tmp/SHA256SUMS "${REL_URL}/SHA256SUMS" \
                 || ! wget -O "/tmp/${SNAND_NAME}.gz" "${REL_URL}/${SNAND_NAME}.gz" \
                 || [ ! -s "/tmp/${SNAND_NAME}.gz" ]; then
                echo "ERROR: Download failed."
                rm -f "/tmp/${SNAND_NAME}.gz"
                exit 1
            fi
            # A half-downloaded or wrong image written to the NAND is a box that does not boot.
            WANT=$(grep " ${SNAND_NAME}.gz\$" /tmp/SHA256SUMS | cut -d' ' -f1)
            GOT=$(sha256sum "/tmp/${SNAND_NAME}.gz" | cut -d' ' -f1)
            if [ -z "$WANT" ] || [ "$WANT" != "$GOT" ]; then
                echo "ERROR: The image does not match SHA256SUMS of the release."
                rm -f "/tmp/${SNAND_NAME}.gz"
                exit 1
            fi
            gunzip -f "/tmp/${SNAND_NAME}.gz"
            NAND_IMG="/tmp/${SNAND_NAME}"
            echo "OK: Downloaded ($(du -h ${NAND_IMG} | cut -f1))."
            ;;
    esac
fi
echo ""

if ! grep -q "fitrw" /proc/mounts 2>/dev/null; then
    echo "ERROR: This script must be run from the SD card!"
    echo "       Make sure the DIP switch is set to SD boot."
    exit 1
fi

echo "OK: System is running from SD card."
echo ""

if [ ! -f "${NAND_IMG}" ]; then
    echo "ERROR: Image file not found: ${NAND_IMG}"
    echo "       Download snand-img.bin to /tmp/ or pass path as argument."
    exit 1
fi

echo "OK: Pro 8X image found ($(du -h ${NAND_IMG} | cut -f1))."
echo ""

if ! grep -q '"nand"' /proc/mtd 2>/dev/null; then
    echo "ERROR: NAND device not found in /proc/mtd!"
    exit 1
fi

echo "OK: NAND device found."
echo ""

echo "WARNING: The entire NAND flash will be overwritten!"
echo "         Press ENTER to continue or CTRL+C to cancel."
read _

echo ""
echo "Flashing Pro 8X image to NAND..."
mtd -e nand write "${NAND_IMG}" nand

echo ""
echo "=================================================="
echo "  DONE! Rescue system installed to NAND."
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Power off the device"
echo "  2. Set DIP switches: A=0, B=1 (NAND boot)"
echo "  3. Power on"
echo "     NOTE: U-Boot may show 'UBI: Bad EC magic in block XXXX' messages."
echo "           This is NORMAL on first boot -- U-Boot is initializing the NAND."
echo "  4. Login via SSH or LuCI (http://192.168.1.1) and run:"
echo "     sh /root/install-dir/install-nvme.sh"
echo ""
