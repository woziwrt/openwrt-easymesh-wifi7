# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
include $(TOPDIR)/rules.mk

PKG_NAME:=easymesh
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/easymesh
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=EasyMesh
  TITLE:=WiFi 7 EasyMesh R6 mesh stack (meta package)
  # Core stack. Both map daemons are installed on every node; the role
  # (controller/agent) is decided at onboarding time by easymesh-config,
  # not by package selection — one package set fits every node.
  DEPENDS:= \
	+map-controller \
	+map-agent \
	+ieee1905 \
	+ieee1905-map-plugin \
	+wifimngr \
	+easymesh-mesh \
	+easymesh-wifi \
	+easymesh-config \
	+easymesh-api \
	+luci-app-easymesh \
	+hostapd-utils \
	+wpa-cli
  PKGARCH:=all
endef

define Package/easymesh/description
  Installs the complete EasyMesh R6 stack: IEEE 1905.1 transport with the
  Multi-AP plugin, Multi-AP controller and agent daemons, and the WiFi HAL
  bridge (wifimngr). Configuration and the LuCI onboarding wizard are
  provided by the companion packages of this feed.

  Requires a base image with mt76 single-wiphy MLO and an MLD-aware
  hostapd (woziwrt BPI-R4 images). A reboot is required after
  installation; the stack does not reconfigure radios at runtime.
endef

define Package/easymesh/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0

# Everything below is for a node that has not been told what it is, and apk
# runs this script on upgrade as well as on install. On a node that already
# has a role it therefore took the role away: measured 2026-08-14, upgrading
# a running controller to r112 left mapcontroller.enabled='0' with both
# daemons stopped and the mesh without a brain. The update path we ship to
# customers ran straight into it.
#
# The marks are the same ones 99-easymesh-no-default-role reads, and for the
# same reason: they are the ones the factory cannot leave. easymesh-role
# agent sets controller_select.local='0' where the factory ships '1';
# easymesh-role controller pairs enabled='1' with dhcp.lan.ignore='0' where
# the factory leaves ignore unset. Either mark means a decision was made -
# and a decision outranks a default, whichever way apk got here.
if [ "$$(uci -q get mapagent.@controller_select[0].local)" = "0" ] ||
   { [ "$$(uci -q get mapcontroller.controller.enabled)" = "1" ] &&
     [ "$$(uci -q get dhcp.lan.ignore)" = "0" ]; }; then
	exit 0
fi

# A freshly installed node must do nothing until its role is chosen. map-agent
# ships mapagent.agent.enabled defaulting to 1 and its postinst starts the
# daemon, and a running agent regenerates the wireless config roughly 90 s
# later: it creates a backhaul AP and a bSTA, restarts the radios under a live
# system and takes the wired socket down with them. The bSTA then chases any
# MAP--BH in range - the SSID is the same everywhere, the key is not - and
# fails to associate over and over (measured 2026-08-13, round 2).
# Both init scripts honour enabled=0, so nothing more is needed here.
# easymesh-role turns the right one back on when the role is picked.
#
# This has to live in the meta package, not in easymesh-config: apk installs
# easymesh-config as 13/31 and map-agent as 26/31, so the same lines placed in
# easymesh-config were undone fourteen steps later by map-agent's own postinst
# (measured 2026-08-13, round 1 rerun). The meta package is 29/31 - after both
# daemons - because it depends on them.
uci -q set mapagent.agent.enabled='0'
uci -q set mapcontroller.controller.enabled='0'
uci -q commit mapagent
uci -q commit mapcontroller
/etc/init.d/mapagent stop >/dev/null 2>&1
/etc/init.d/mapcontroller stop >/dev/null 2>&1

# bh-key-adopt has to be quiet as well, and it is the one that bites.
#
# It exists for the join: credentials arrive over WSC, it builds both backhaul
# sides from them, and reboots - deliberately, because a runtime wifi reload
# assigns chanctx wrongly on MT7996. What it watches for is "a mapagent
# backhaul section carries a key", and it cannot tell a delivered key from the
# fallback map-controller writes into its own defaults during installation.
#
# It also starts nine steps before that happens: easymesh-wifi is 6/31,
# map-controller is 15/31, so by the time the fallbacks are written the daemon
# has been running for a while and simply notices them.
#
# Measured 2026-08-13 on a freshly flashed board: apk add finished cleanly and
# the box rebooted itself 85 s later, unasked. Ten rounds of the install test
# had missed it because every one of them rebooted the box manually before the
# daemon got that far - our own habit was hiding it.
#
# It did not reproduce on the next attempt, so what fills those keys, and why
# only sometimes, is still open. This does not depend on the answer: a node
# that has not been told what it is has nothing to adopt, whatever ends up in
# its config.
/etc/init.d/bh-key-adopt stop >/dev/null 2>&1
exit 0
endef

define Build/Compile
endef

define Package/easymesh/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-easymesh-no-default-role $(1)/etc/uci-defaults/99-easymesh-no-default-role
endef

$(eval $(call BuildPackage,easymesh))
