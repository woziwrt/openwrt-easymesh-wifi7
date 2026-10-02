# Installers

Imported on 2026-10-01 unchanged from `woziwrt/bpi-r4-deploy`, the scripts its releases ship:

| here | from | commit |
|---|---|---|
| `r4/install-nand.sh`, `r4/install-emmc.sh`, `r4/install-nvme.sh` | `main:my_files/bpi-r4-install/` | `d1cbf1afcb0b` |
| `pro-8x/install-nand-pro8x.sh`, `pro-8x/install-emmc-pro8x.sh`, `pro-8x/install-nvme-pro8x.sh`, `pro-8x/boot-nvme` | `pro-8x-unifi:my_files/bpi-r4-install/` | `8f643ccb2c58` |

The path they describe: a rescue SD card boots, `install-nand*.sh` writes a NAND system to the SPI-NAND, the box boots from
NAND (SD and eMMC share one controller, so eMMC can only be written from NAND), and `install-emmc*.sh` /
`install-nvme*.sh` write the real image there.

**In the image:** the build copies the installers of its board to `/root/install-dir/` under the names bpi-r4-deploy
used - `install-nand.sh`, `install-emmc.sh`, `install-nvme.sh` (and `boot-nvme` on the Pro 8X). They are on the SD
image and on the NAND system alike, so the whole path runs from the box itself.

**Where they download from:** this repository's lab release `lab-emmc-rc4` by default (`TAG=<release tag>` for
another); every download is checked against that release's `SHA256SUMS`. The board is told by its memory (BPI-R4
4 GB / 8 GB); the menus of bpi-r4-deploy's variants (wired, PoE, UniFi) are gone.

**The NAND system:** the BPI-R4 NAND is 128 MiB, so its NAND devices (`bananapi_bpi-r4-nand`, `-nand-8gb`) drop
docker per device and add `wipefs` and `smartmontools` (boards/bpi-r4/filogic.mk). The Pro 8X has a 256 MiB NAND
and uses its full image.

## Status (2026-10-02)

| script | adapted to this repository | tested on hardware |
|---|---|---|
| `r4/install-nand.sh` | yes - lab release, board by memory, SHA256SUMS | not yet |
| `r4/install-emmc.sh` | yes | not yet |
| `r4/install-nvme.sh` | yes | not yet |
| `pro-8x/install-nand-pro8x.sh` | yes - lab release, SHA256SUMS | not yet |
| `pro-8x/install-emmc-pro8x.sh` | yes | not yet |
| `pro-8x/install-nvme-pro8x.sh` | yes - the sysupgrade image is stored on p1 as `bpi-r4-pro-8x.itb` | not yet |
| `pro-8x/boot-nvme` | nothing to adapt (no download) | not yet |

Until these are tested, the release supports the SD card only.
