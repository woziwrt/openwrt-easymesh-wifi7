# Changes to the iopsys Multi-AP stack

`overlay/` holds every file we add to or change in the
[iopsys feed](https://dev.iopsys.eu/feed/iopsys) (ieee1905, map-agent,
map-controller, libwifi, libeasy, wifimngr). The build clones upstream at
`IOPSYS_BASE` (see [`../pins.conf`](../pins.conf)), copies `overlay/` on top and
checks that the result has the git tree `IOPSYS_TREE` - so nothing can be lost
or changed on the way without the build stopping.

Most of the overlay is patch series under `<package>/patches/`, applied to the
package sources by the OpenWrt build like any other package patch. The few
modified package files (Makefiles, init and uci-defaults scripts) are iopsys
files with our changes and keep their original copyright.

## Node names in measurements

Patch descriptions quote measurements from our test mesh and name the nodes by
their board:

| name | board |
|---|---|
| `4g`, `bpi-4g` | Banana Pi BPI-R4, 4 GB |
| `8g`, `bpi-8g` | Banana Pi BPI-R4, 8 GB |
| `x8`, `bpi-x8` | Banana Pi BPI-R4 Pro 8X |
| kitchen, corridor, hall, bedroom | BPI-R4 nodes of the later test mesh, named by room |
