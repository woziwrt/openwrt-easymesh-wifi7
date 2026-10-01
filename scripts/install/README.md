# Installers (imported, not adapted yet)

Imported on 2026-10-01 unchanged from `woziwrt/bpi-r4-deploy`, the scripts its releases ship:

| here | from | commit |
|---|---|---|
| `r4/install-nand.sh`, `r4/install-emmc.sh`, `r4/install-nvme.sh` | `main:my_files/bpi-r4-install/` | `d1cbf1afcb0b` |
| `pro-8x/install-nand-pro8x.sh`, `pro-8x/install-emmc-pro8x.sh`, `pro-8x/install-nvme-pro8x.sh`, `pro-8x/boot-nvme` | `pro-8x-unifi:my_files/bpi-r4-install/` | `8f643ccb2c58` |

The path they describe: a rescue SD card boots, `install-nand*.sh` writes a lean system to the SPI-NAND, the box boots from
NAND (SD and eMMC share one controller, so eMMC can only be written from NAND), and `install-emmc*.sh` / `install-nvme*.sh`
write the real image there. Still to do before they serve this repository: download from this repository's releases,
our image names (`.bin.gz`), only our three boards, and an NVMe image the build does not produce yet.
