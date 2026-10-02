# Installing to eMMC or NVMe (experimental)

The release runs from the **SD card**, and that is the way we recommend for trying it. **For permanent use, the main box
is better on eMMC or NVMe:** it writes its database and logs all the time, SD cards wear out under that, and a slow one
stalls the main box. This page is for those who want the system there.

**Installing starts the box from scratch:** it loses its mesh settings, and if it is the main box, you build the mesh
again and pair every other box again. **The easiest time to move the main box is before you build the mesh.**

> **Experimental.** The installers live on the `emmc-nvme` branch. Tested in our lab on 2 Oct 2026, with the downloads
> served from a local copy of the release (the download from GitHub itself was first run when this was published):
> **BPI-R4 4 GB** SD → NAND → eMMC and NAND → NVMe, **BPI-R4 8 GB** SD → NAND → eMMC; each time the box then joined the
> mesh with the WPS button like any other. **BPI-R4 Pro 8X** SD → NAND → eMMC (installed and booted) and NAND → NVMe
> (installed, booted and joined the mesh).
> **Step 1 erases the whole NAND; step 2 erases the whole eMMC or the whole NVMe disk** - every partition, not just the
> space the system needs.

## How it works

The SD card and the eMMC share one controller, so the eMMC cannot be written while the box runs from the SD card. The
path is therefore:

1. boot from the **SD card** and write a small rescue system to the board's **NAND**;
2. boot from the **NAND** and write the real system to the **eMMC** or the **NVMe** disk;
3. boot from it and add the box to the mesh as usual.

Nothing on the SD card is changed. **Keep the SD card:** it is the way back from every other medium (see *Going back*).

A box that has not been named yet is called `BPI-R4-` and the last six digits of its own address, e.g. `BPI-R4-da55f9`
(the Pro 8X too). The images from this page add where the box runs: `BPI-R4-NAND-da55f9`, `BPI-R4-eMMC-da55f9`,
`BPI-R4-NVMe-da55f9`. The SD image of `v0.1-preview` does not.

The NAND system is for rescue and installing only: it has little room (about 40 MB free on a 128 MiB NAND) and is not
meant to run the mesh.

## What you need

- the box running the release SD image (see the README);
- **a cable from the box's WAN port to your internet router** - the installers download the images from this repository's
  [lab release](https://github.com/woziwrt/openwrt-easymesh-wifi7/releases/tag/lab-emmc-rc4) and check every file
  against its `SHA256SUMS`;
- **a computer on the box's service port** (LAN3 on the BPI-R4, LAN1 on the Pro 8X), straight, without a switch. It
  answers at `192.168.1.1` whether or not the box is in a mesh, and gives your computer an address there. *(On a box
  that has never been in a mesh, any LAN port works too.)* If your computer gets no address, give it `192.168.1.2`,
  mask `255.255.255.0`.
- Log in with `ssh root@192.168.1.1`. The SD system asks for your root password if you set one; the NAND system has none.
  **Each system on the box (SD, NAND, eMMC, NVMe) has its own SSH key at the same address**, so after switching your
  computer refuses to connect (*REMOTE HOST IDENTIFICATION HAS CHANGED*). That is expected here: run
  `ssh-keygen -R 192.168.1.1` and log in again.

**Back up the NAND first** if it holds anything you may want again (the factory system, another OpenWrt): step 1 erases
all of it. From the SD system: `cat /proc/mtd` shows the NAND (`spi0.0` on the BPI-R4, `nand` on the Pro 8X, e.g.
`mtd0`); `cat /dev/mtd0 > /tmp/nand-backup.bin` and copy the file to your computer
(`scp root@192.168.1.1:/tmp/nand-backup.bin .`).

**While the box runs the NAND system or a fresh eMMC/NVMe system, it has no root password and its Wi-Fi `OpenWrt-MLD`
uses the published key `12345678`:** anyone in range can log in. Install with nobody else around, and set a root
password as soon as the box is in the mesh.

Boot switch positions (SW3), the same on the BPI-R4 and the Pro 8X. **Unplug the power before switching** (the boards
have no power switch):

| boot from | A | B |
|---|---|---|
| SD card | 1 | 1 |
| NAND | 0 | 1 |
| eMMC | 1 | 0 |

## What the installer asks

The answers are typed and confirmed with Enter.

| question | answer |
|---|---|
| BPI-R4 only: **Select your board** - BPI-R4 4 GB or 8 GB | Enter takes the one this box reports; the 4 GB and 8 GB images differ and the wrong one does not boot |
| **File source** - download or a local file | `1` (download) |
| **Is ethernet connected?** | `yes` (the WAN cable) |
| **Type YES to confirm** - erases the target | `YES` |
| NVMe only: **Disk has warnings. Continue anyway?** - shown when the disk's health check (SMART) reports something | your call: `y` continues; a disk that fails the check stops the installer by itself |
| **Pro 8X NAND installer only:** cable `[y/N]`, and **Enter** instead of `YES` | `y`, then **Enter writes the NAND** - Ctrl+C cancels |

The BPI-R4 installers do not check that the board is a BPI-R4: **on a Pro 8X use only the Pro 8X installers.**

## BPI-R4 (4 GB and 8 GB)

The release SD image does not contain the installers - download each one as shown, it takes one `wget`.
**Do not run the copies in `/root/install-dir/`** on the NAND system: they can be older than the ones here.

**1. From the SD card: write the NAND rescue system**
```sh
wget -O /tmp/install-nand.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-nand.sh
sh /tmp/install-nand.sh
```
When it says *NAND installation complete*: unplug the power, set the switch to **NAND (A=0, B=1)**, plug in. The first
start from NAND takes a few minutes. Log in again (`ssh-keygen -R 192.168.1.1`, then `ssh root@192.168.1.1`, no password).

**2a. From NAND: install to the eMMC**
```sh
wget -O /tmp/install-emmc.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-emmc.sh
sh /tmp/install-emmc.sh
```
When it says *Installation complete*: unplug the power, set the switch to **eMMC (A=1, B=0)**, plug in.

**2b. From NAND: install to the NVMe disk**
```sh
wget -O /tmp/install-nvme.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/r4/install-nvme.sh
sh /tmp/install-nvme.sh
```
It checks the disk's health first, writes the system and restarts by itself. **Leave the switch on NAND**: the NAND boot
loader starts the system from the NVMe from now on.

**3. Into the mesh**

The installed box starts empty, without the mesh settings it had on the SD card.

- **Any box but the main one:** pair it again with the WPS button, as in the README (*Getting started*, step 3).
- **The main box:** it starts a new mesh. The other boxes do not follow it by themselves: create the mesh again on it
  and pair every other box again.

**Names.** A box installed this way calls itself `BPI-R4-eMMC-…` or `BPI-R4-NVMe-…` until it gets a name.
- If the main box runs an image from this page too, a box that was in the mesh before gets its old name back by itself.
- **If the main box runs the `v0.1-preview` SD card,** it does not recognise these names as unnamed: it takes
  `BPI-R4-eMMC-…` as the box's real name and forgets the old one. Give the box its name again in LuCI (*Nodes*).
  Nothing else is affected - the mesh tells boxes apart by their address, not their name. Fixed in the next release.

## BPI-R4 Pro 8X

The same three steps with the Pro 8X installers; the switch positions are the same (table above). The Pro 8X has a
256 MiB NAND and runs the full image there.

**1. From the SD card: NAND**
```sh
wget -O /tmp/install-nand-pro8x.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/pro-8x/install-nand-pro8x.sh
sh /tmp/install-nand-pro8x.sh
```
It asks `[y/N]` for the cable (answer `y`) and, instead of `YES`, **Enter** to write - Ctrl+C cancels. The first start
from NAND took about three minutes in our lab and may print `UBI: Bad EC magic` lines; that is normal.

**2a. From NAND: eMMC**
```sh
wget -O /tmp/install-emmc-pro8x.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/pro-8x/install-emmc-pro8x.sh
sh /tmp/install-emmc-pro8x.sh
```
Then switch to **eMMC (A=1, B=0)**.

**2b. From NAND: NVMe**
```sh
wget -O /tmp/install-nvme-pro8x.sh https://raw.githubusercontent.com/woziwrt/openwrt-easymesh-wifi7/emmc-nvme/scripts/install/pro-8x/install-nvme-pro8x.sh
sh /tmp/install-nvme-pro8x.sh
```
Leave the switch on NAND; it restarts by itself into the NVMe system. **If your Pro 8X has two NVMe disks, take out the
one you want to keep before you install:** the installer lists the disks only by name (`nvme0n1`, `nvme1n1`) and erases
the one you pick.

**3. Into the mesh** - as on the BPI-R4 above. A Pro 8X may restart twice while it joins; give it 10-15 minutes.

## Going back

- **To the SD card:** set the switch to SD (A=1, B=1). The SD system starts as it was.
- **A former main box:** if you have built the mesh again from its eMMC/NVMe system, do not bring its old SD system
  back while the new mesh runs - it is still the main box of the old mesh, and a mesh has only one. Write the SD card
  again first.
- **From the NVMe back to the NAND rescue system on a BPI-R4:** not automated yet - for now use the SD card.

## Known gaps

- **Do not upgrade an eMMC or NVMe system with `sysupgrade` yet** - it has not been tested, and on the NVMe the system is
  stored in two places that an upgrade may not both update. To move to a newer release, run the installer again (the box
  then starts empty, see step 3). The `v0.1-preview` sysupgrade file is for SD cards.
- The installers check the download thoroughly, but not every step after it: a step that fails late can still end with
  *Installation complete*. If the box does not start from the new medium, switch back to NAND (or SD), run the
  installer again and send us its whole output.
- On a BPI-R4 running from the NVMe, the boot loader settings cannot be changed from the running system; the way back
  to the NAND rescue system is the SD card.
- `boot-nand` / `boot-nvme` (Pro 8X, in `/usr/sbin`, to switch between the NVMe and the NAND rescue system) have not
  been tested yet.
- The Pro 8X images have no `smartctl`, so its NVMe installer skips the disk health check.

Questions and reports are welcome as issues; please say which board, which medium and attach the installer's output.
