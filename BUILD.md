# Building the images

Two production images are built from this repository, one per board:

| Board | Script | Output |
|---|---|---|
| Banana Pi BPI-R4 (4 GB and 8 GB) | `./build-bpi-r4.sh` | `output/<date>-bpi-r4/` |
| Banana Pi BPI-R4 Pro 8X | `./build-bpi-r4-pro-8x.sh` | `output/<date>-bpi-r4-pro-8x/` |

Both images carry the complete EasyMesh stack (controller and agent); the role
of a box is chosen after the first boot, not at build time.

## Requirements

- A Linux build host that can build OpenWrt 25.12 (see the
  [OpenWrt build system prerequisites](https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem)),
  plus `python3` and `git`.
- About 60 GB of free disk space per board and several hours for the first build.
- Network access to github.com and dev.iopsys.eu.

## Build

```sh
git clone https://github.com/woziwrt/openwrt-easymesh-wifi7.git
cd openwrt-easymesh-wifi7
./build-bpi-r4.sh
```

The build writes its own log to `output/build-<board>-<time>.log`.

The two boards use separate build trees (`build/bpi-r4/`, `build/bpi-r4-pro-8x/`)
and may be built at the same time. Do not start two builds of the same board at
once - the script deletes and recreates its own tree.

## What a build does

1. Checks that the repository has no uncommitted changes (an image built from
   uncommitted files cannot be reproduced; `ALLOW_DIRTY=1` overrides).
2. Clones OpenWrt, the MediaTek feed and the iopsys Multi-AP stack at the
   revisions in [`pins.conf`](pins.conf), and copies our iopsys changes
   ([`iopsys/overlay/`](iopsys/overlay)) on top. The resulting iopsys tree must
   match the hash in `pins.conf`, otherwise the build stops.
3. Applies the Wi-Fi patches ([`patches/wifi/`](patches/wifi)) and the kernel,
   U-Boot and board patches.
4. Adds our package feed ([`feed/`](feed)) and assembles the configuration:
   [`configs/`](configs) plus the EasyMesh package set in
   [`scripts/common.sh`](scripts/common.sh).
5. Checks the final configuration - the whole mesh stack must be built in
   (`=y`), a device must be selected - and stops before the long compile if not.
6. Builds, then copies images, SDK, ImageBuilder, our packages and a manifest of
   all revisions into `output/`.

## Options (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `WORK_DIR` | `build/<board>` | build tree |
| `DL_DIR` | `dl/` | download cache, shared by both boards |
| `MIRROR_DIR` | `~/mirrors` | local `git clone --mirror` copies of openwrt, mtk-openwrt-feeds and iopsys, used when present to speed up cloning |
| `OUTPUT_DIR` | `output/` | where finished images go |
| `OPENWRT_COMMIT`, `MTK_COMMIT`, `IOPSYS_BASE`, `IOPSYS_TREE` | `pins.conf` | override a pin for a trial build (the result is then not the tested image) |
| `ALLOW_DIRTY=1` | off | build from uncommitted changes |
| `LOG_FILE` | `output/build-<board>-<time>.log` | build log |

Settings for one machine can be kept in `local.conf` in the repository root
(ignored by git), e.g. `DL_DIR=$HOME/dl-shared`.

## Repository layout

```
build-bpi-r4.sh, build-bpi-r4-pro-8x.sh   board scripts (only what differs per board)
scripts/common.sh                         everything shared: sources, Wi-Fi, mesh, checks
pins.conf                                 all upstream revisions
feed/                                     our OpenWrt packages (EasyMesh, LuCI)
iopsys/overlay/                           our changes to the iopsys Multi-AP stack
patches/wifi/                             hostapd, mt76 and mac80211 patches
patches/luci/                             changes to LuCI itself (remove-password button)
patches/mtk-feed/, patches/kernel/, patches/uboot/   patches shared by both boards
boards/<board>/                           board patches, image layout, first-boot files
configs/                                  OpenWrt configuration
```
