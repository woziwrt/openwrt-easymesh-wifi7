# Installing to eMMC or NVMe (experimental)

The release runs from the **SD card**, and that is the way we recommend for trying it. **For permanent use, the main box
is better on eMMC or NVMe:** it writes its database and logs all the time, SD cards wear out under that, and a slow one
stalls the main box. This page is for those who want the system there.

> **Experimental.** The installers live on the `emmc-nvme` branch. Tested in our lab on 2 Oct 2026:
> **BPI-R4 4 GB** SD → NAND → eMMC and NAND → NVMe, **BPI-R4 8 GB** SD → NAND → eMMC; each time the box then joined the
> mesh with the WPS button like any other. **The BPI-R4 Pro 8X scripts exist but have not been run on hardware yet.**
> Installing erases the target (eMMC or NVMe) completely.

## How it works

The SD card and the eMMC share one controller, so the eMMC cannot be written while the box runs from the SD card. The
path is therefore:

1. boot from the **SD card** and write a small rescue system to the board's **NAND**;
2. boot from the **NAND** and write the real system to the **eMMC** or the **NVMe** disk;
3. boot from it and add the box to the mesh as usual.

Nothing on the SD card is changed: switching back to SD always brings the SD system back. A box that has not been named
yet shows where it runs in its name - `BPI-R4-SD-…`, `BPI-R4-NAND-…`, `BPI-R4-eMMC-…`, `BPI-R4-NVMe-…`.

The NAND system is for rescue and installing only: it has little room (about 40 MB on a 4 GB BPI-R4) and is not meant
to run the mesh.

## What you need

- the box running the release SD image (see the README);
- **a cable from the box's WAN port to your internet router** - the installers download the images from this repository's
  [lab release](https://github.com/woziwrt/openwrt-easymesh-wifi7/releases/tag/lab-emmc-rc4) and check every file
  against its `SHA256SUMS`;
- **a computer on a LAN port of the box** (not the WAN port). It gets an address from the box; log in with
  `ssh root@192.168.1.1`. The SD system asks for your root password if you set one; the NAND system has none.

Boot switch positions on the BPI-R4 (SW3), power off before switching:

| boot from | A | B |
|---|---|---|
| SD card | 1 | 1 |
| NAND | 0 | 1 |
| eMMC | 1 | 0 |

## What the installer asks

Every installer asks the same few questions; the answers are typed and confirmed with Enter.

| question | answer |
|---|---|
| **Select your board** - BPI-R4 4 GB or 8 GB | Enter takes the one this box reports; the 4 GB and 8 GB images differ and the wrong one does not boot |
| **File source** - download or a local file | `1` (download) |
| **Is ethernet connected?** | `yes` (the WAN cable) |
| **Type YES to confirm** - erases the target | `YES` |
| NVMe only: **Disk has warnings. Continue anyway?** - shown when the disk's health check (SMART) reports something | your call: `y` continues |

## BPI-R4 (4 GB and 8 GB)

The release SD image does not contain the installers - download each one as shown, it takes one `wget`. (The NAND
system written in step 1 carries copies in `/root/install-dir/`, but download the installer fresh anyway: the copies
may be older.)

**1. From the SD card: write the NAND rescue system**
```sh
wget -O /tmp/install-nand.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-nand.sh
sh /tmp/install-nand.sh
```
When it says *NAND installation complete*: power off, set the switch to **NAND (A=0, B=1)**, power on. The first start
from NAND takes a little longer. Log in again (`ssh root@192.168.1.1`, no password).

**2a. From NAND: install to the eMMC**
```sh
wget -O /tmp/install-emmc.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-emmc.sh
sh /tmp/install-emmc.sh
```
When it says *Installation complete*: power off, set the switch to **eMMC (A=1, B=0)**, power on.

**2b. From NAND: install to the NVMe disk**
```sh
wget -O /tmp/install-nvme.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-nvme.sh
sh /tmp/install-nvme.sh
```
It checks the disk's health first, writes the system and restarts by itself. **Leave the switch on NAND**: the NAND boot
loader starts the system from the NVMe from now on.

**3. Into the mesh**

The installed box is a fresh one: make it the main box or pair it with the WPS button, exactly as in the README
(*Getting started*, steps 2 and 3). A box that was in the mesh before gets its old name back.

## BPI-R4 Pro 8X

The same path with the scripts in `scripts/install/pro-8x/` (`install-nand-pro8x.sh`, `install-emmc-pro8x.sh`,
`install-nvme-pro8x.sh`) - **not tested on hardware yet**. The Pro 8X has a 256 MiB NAND and uses its full image there.
`boot-nand` and `boot-nvme` (in `/usr/sbin`) switch between the NVMe and the NAND rescue system. Follow the switch
positions the scripts print.

## Going back

- **To the SD card:** set the switch to SD (A=1, B=1). The SD system starts as it was.
- **From the NVMe back to the NAND rescue system on a BPI-R4:** not automated yet - for now use the SD card.

## Known gaps

- On a BPI-R4 running from the NVMe, the boot loader settings cannot be changed from the running system.
- Upgrading an eMMC or NVMe system works with `sysupgrade` like on the SD card, but has not been tested yet.

Questions and reports are welcome as issues; please say which board, which medium and attach the installer's output.
