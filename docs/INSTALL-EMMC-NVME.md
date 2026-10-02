# Installing to eMMC or NVMe (experimental)

The release runs from the **SD card**, and that is the way we recommend for trying it. **For permanent use, the main box
is better on eMMC or NVMe:** it writes its database and logs all the time, SD cards wear out under that, and a slow one
stalls the main box. This page is for those who want the system there.

The NAND system written on the way is for rescue and installing only: it has little room (about 40 MB on a 4 GB
BPI-R4) and is not meant to run the mesh.

> **Experimental.** The installers live on the `emmc-nvme` branch and were tested once, on one BPI-R4 4 GB in our lab
> (2 Oct 2026): SD → NAND → eMMC and NAND → NVMe, after which the box joined the mesh with the WPS button like any other.
> The BPI-R4 8 GB uses the same scripts with its own images. **The BPI-R4 Pro 8X scripts exist but have not been run on
> hardware yet.** Installing erases the target (eMMC or NVMe) completely.

## Why it goes through the NAND

The SD card and the eMMC share one controller, so the eMMC cannot be written while the box runs from the SD card. The
path is therefore: boot from SD → write a small rescue system to the board's SPI-NAND → boot from NAND → write the eMMC
or the NVMe from there → boot from it. Nothing on the SD card is changed: switching back to SD always brings the SD
system back.

## What you need

- the box running the release SD image (see the README);
- **a cable from the box's WAN port to your internet router** - the installers download the images from this repository's
  [lab release](https://github.com/woziwrt/openwrt-easymesh-wifi7/releases/tag/lab-emmc-rc4) and check them against its
  `SHA256SUMS`;
- a computer on a LAN port of the box, and `ssh root@192.168.1.1` (the NAND system has no password, like any fresh OpenWrt).

Boot switch positions on the BPI-R4 (SW3):

| boot from | A | B |
|---|---|---|
| SD card | 1 | 1 |
| NAND | 0 | 1 |
| eMMC | 1 | 0 |

## BPI-R4 (4 GB and 8 GB)

The scripts ask which board it is (4 GB or 8 GB) and offer the one the box reports; the two need different images.
Always download the scripts fresh from GitHub as shown - the copies inside the NAND system may be older.

**1. From the SD card: write the NAND rescue system**
```sh
wget -O /tmp/install-nand.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-nand.sh
sh /tmp/install-nand.sh
```
Power off, set the switch to **NAND (A=0, B=1)**, power on. The first start from NAND takes a little longer.

**2a. From NAND: install to the eMMC**
```sh
wget -O /tmp/install-emmc.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-emmc.sh
sh /tmp/install-emmc.sh
```
Power off, set the switch to **eMMC (A=1, B=0)**, power on.

**2b. From NAND: install to the NVMe disk**
```sh
wget -O /tmp/install-nvme.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-nvme.sh
sh /tmp/install-nvme.sh
```
It checks the disk's health (SMART) first, writes the system to it and restarts. **Leave the switch on NAND**: the NAND
boot loader starts the system from the NVMe from now on.

**3. Into the mesh**

The installed box is a fresh one: make it the main box or pair it with the WPS button, exactly as in the README
(*Getting started*, steps 2 and 3). A box that was in the mesh before keeps its name.

## BPI-R4 Pro 8X

The same path with the scripts in `scripts/install/pro-8x/` (`install-nand-pro8x.sh`, `install-emmc-pro8x.sh`,
`install-nvme-pro8x.sh`) - **not tested on hardware yet**. The Pro 8X has a 256 MiB NAND and uses its full image there.
On the Pro 8X, `boot-nand` and `boot-nvme` (in `/usr/sbin` of the NAND system) switch between the NVMe and the NAND
rescue system.

## Going back

- **To the SD card:** set the switch to SD (A=1, B=1). The SD system starts as it was.
- **From the NVMe back to the NAND rescue system on a BPI-R4:** not automated yet - for now use the SD card.

## Known gaps

- The box does not yet rename itself after the medium it runs from.
- On a BPI-R4 running from the NVMe, the boot loader settings cannot be changed from the running system.
- Upgrading an eMMC or NVMe system works with `sysupgrade` like on the SD card, but has not been tested yet.

Questions and reports are welcome as issues; please say which board, which medium and attach the installer's output.
