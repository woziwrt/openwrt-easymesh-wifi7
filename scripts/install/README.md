# Installers

Imported on 2026-10-01 from `woziwrt/bpi-r4-deploy` (the scripts its releases ship) and adapted - release, board by
memory, SHA256SUMS:

| here | from | commit |
|---|---|---|
| `r4/install-nand.sh`, `r4/install-emmc.sh`, `r4/install-nvme.sh` | `main:my_files/bpi-r4-install/` | `d1cbf1afcb0b` |
| `pro-8x/install-nand-pro8x.sh`, `pro-8x/install-emmc-pro8x.sh`, `pro-8x/install-nvme-pro8x.sh`, `pro-8x/boot-nvme` | `pro-8x-unifi:my_files/bpi-r4-install/` | `8f643ccb2c58` |
| `pro-8x/boot-nand` (added 2026-10-02) | `pro-8x-unifi:my_files/bpi-r4-pro/files/usr/sbin/` | `8f643ccb2c58` |

The path they describe: a rescue SD card boots, `install-nand*.sh` writes a NAND system to the SPI-NAND, the box boots from
NAND (SD and eMMC share one controller, so eMMC can only be written from NAND), and `install-emmc*.sh` /
`install-nvme*.sh` write the real image there.

**In the image:** the build copies the installers of its board to `/root/install-dir/` under the names bpi-r4-deploy
used - `install-nand.sh`, `install-emmc.sh`, `install-nvme.sh`, and on the Pro 8X `boot-nand` / `boot-nvme` in `/usr/sbin` (switch between the NVMe and the
NAND rescue system). `install-nvme-unifi.sh` of bpi-r4-deploy is left out: it belongs to the UniFi stack. They are in the images
built from this branch (SD and NAND). The `v0.1-preview` SD image is built from `main` and has none, and the copies
in an image can be older than the scripts here - download them as `docs/INSTALL-EMMC-NVME.md` shows.

**Where they download from:** this repository's lab release `lab-emmc-rc4` by default (`TAG=<release tag>` for
another); every download is checked against that release's `SHA256SUMS`. The board is told by its memory (BPI-R4
4 GB / 8 GB); the menus of bpi-r4-deploy's variants (wired, PoE, UniFi) are gone.

**The NAND system:** the BPI-R4 NAND is 128 MiB on our 4 GB board (256 MiB on our 8 GB one), so its NAND devices (`bananapi_bpi-r4-nand`, `-nand-8gb`) drop
docker per device and add `wipefs` and `smartmontools` (boards/bpi-r4/filogic.mk). The Pro 8X has a 256 MiB NAND
and uses its full image.

## Status (2026-10-02)

| script | adapted to this repository | tested on hardware |
|---|---|---|
| `r4/install-nand.sh` | yes - lab release, board by memory, SHA256SUMS | 2026-10-02: BPI-R4 4 GB and 8 GB |
| `r4/install-emmc.sh` | yes | 2026-10-02: BPI-R4 4 GB and 8 GB |
| `r4/install-nvme.sh` | yes | 2026-10-02: BPI-R4 4 GB |
| `pro-8x/install-nand-pro8x.sh` | yes - lab release, SHA256SUMS | 2026-10-02 |
| `pro-8x/install-emmc-pro8x.sh` | yes | 2026-10-02 |
| `pro-8x/install-nvme-pro8x.sh` | yes - the sysupgrade image is stored on p1 as `bpi-r4-pro-8x.itb` | 2026-10-02 |
| `pro-8x/boot-nvme`, `pro-8x/boot-nand` | nothing to adapt (no download); in `/usr/sbin` | not yet |

Tested on 2 Oct 2026 with the downloads served from a local copy of the release; on 4 Oct 2026 the BPI-R4 4 GB path
(`install-nand.sh`, `install-emmc.sh`, `install-nvme.sh`) ran with every download straight from GitHub. The release supports
the SD card; installing to eMMC/NVMe is experimental (`docs/INSTALL-EMMC-NVME.md` on `main`).
