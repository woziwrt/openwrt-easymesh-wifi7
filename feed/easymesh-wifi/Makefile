# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
include $(TOPDIR)/rules.mk

PKG_NAME:=easymesh-wifi
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/easymesh-wifi
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=EasyMesh
  TITLE:=EasyMesh WiFi/MLD runtime (event map, MLD keepers, backhaul setup)
  DEPENDS:=+ubus +uci +wifimngr +easymesh-core
endef

define Package/easymesh-wifi/description
  The runtime layer between the Multi-AP daemons and the radios. Until now
  these files were baked into the woziwrt images, which meant a node built by
  installing packages onto a stock image looked healthy while missing most of
  its plumbing. Measured on such a node 2026-08-07: wifimngr held 1 event
  socket instead of 13, the backhaul STA sat outside br-lan, and three legacy
  per-radio BSSes were still on the air.

  wifi-evmap         - generates /etc/wifi.json. Without it
                       wifimngr_setup_events() fails on its first step and
                       registers no event source at all, so client
                       association is discovered by polling minutes later
                       instead of from the event within ~0.1 s.
  evsrc-check        - verifies the event sources actually came up.
  easymesh-bh-rescue - leaves a parent the backhaul cannot use (most pings to
                       the controller lost, a much stronger parent heard)
  easymesh-fdb-guard - forgets learned bridge entries when the backhaul tree
                       changes, on every box (a moved MAC is not learned again)
  mld-bsta-relink    - keeps the backhaul MLD on every link it is configured
                       for. An MLD STA fixes its link set at association
                       time, so a link still sitting out a DFS CAC is lost
                       for the lifetime of the association.
  mld-link-check     - watches per-link state of the backhaul.
  mld-config-check   - catches MLD sections that were renamed or dropped.
  mld-report-check   - catches AP-MLD reporting gaps.
  mlo-backhaul-setup - stands up the real MLO backhaul: an AP-MLD on the
                       serving node and an MLD STA on the leaf. An MLD STA
                       cannot associate to per-radio BSSes, so without this
                       the backhaul silently degrades to a single link.
  wnm-enable         - turns on BSS transition management. It is off by
                       default in OpenWrt, and with it off hostapd discards
                       every BTM response, so steering reports nothing.
  node-heartbeat     - periodic liveness marker for the node.
  easymesh-logkeep   - keeps the log on the overlay, rotated at each boot, so
                       the previous boot survives the reboot that ended it.
  easymesh-logcap    - keeps the daemon logs in /tmp from eating the RAM they
                       live in. Measured 2026-09-06: 168 MB across five nodes
                       after 13 hours, growing 2-3 MB/h each. Capped, not
                       switched off - that morning the root of a month-old
                       defect was found in exactly those logs.
  beacon-kick        - switches on the beacon of an AP-MLD link that hostapd
                       never sent a second beacon set to. On a node that also
                       runs a bSTA on the same radio the 6 GHz backhaul link
                       comes up associating and forwarding traffic while never
                       transmitting a beacon; measured 2026-09-21, its children
                       read `beacon rx: 0` for ten hours and sent a nullfunc
                       every two seconds. One UPDATE_BEACON repairs it with no
                       reload and no client drop.
  hostapd-watch      - reports a hostapd or wpa_supplicant that stopped
                       answering ubus. A wedged one keeps the radios on the
                       air and the links up, so the node looks healthy while
                       everything that reads it through ubus reads nothing -
                       which is how one wedge produced four false findings on
                       2026-08-16. Reports only; it never restarts anything.
  mld-bsta-bridge    - keeps the backhaul STA on the bridge its wireless
                       section asks for. netifd can bring it up with no
                       bridge master while still counting it as a member,
                       and the split never heals by itself: the association
                       looks healthy and the node has no data path at all.
                       Polled, because the matching hotplug event was
                       measured never to arrive for this interface.

  A reboot is required after installation.
endef

define Build/Compile
endef

define Package/easymesh-wifi/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/init.d $(1)/etc/uci-defaults $(1)/etc/hotplug.d/net $(1)/usr/share/easymesh

	$(INSTALL_DATA) ./files/usr-share/boot-window.sh $(1)/usr/share/easymesh/boot-window.sh
	$(INSTALL_DATA) ./files/usr-share/addr.sh $(1)/usr/share/easymesh/addr.sh
	$(INSTALL_DATA) ./files/usr-share/join-health.sh $(1)/usr/share/easymesh/join-health.sh
	$(INSTALL_DATA) ./files/usr-share/parent-plan.awk $(1)/usr/share/easymesh/parent-plan.awk

	$(INSTALL_BIN) ./files/hotplug/20-mld-bsta-bridge $(1)/etc/hotplug.d/net/20-mld-bsta-bridge

	$(INSTALL_BIN) ./files/usr-sbin/mld-bsta-bridge $(1)/usr/sbin/mld-bsta-bridge
	$(INSTALL_BIN) ./files/usr-sbin/drop-legacy-fronthaul $(1)/usr/sbin/drop-legacy-fronthaul
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-genconfig $(1)/usr/sbin/easymesh-genconfig
	$(INSTALL_BIN) ./files/usr-sbin/bh-roam-safe $(1)/usr/sbin/bh-roam-safe
	$(INSTALL_BIN) ./files/init.d/easymesh-genconfig $(1)/etc/init.d/easymesh-genconfig
	$(INSTALL_BIN) ./files/usr-sbin/wifi-evmap $(1)/usr/sbin/wifi-evmap
	$(INSTALL_BIN) ./files/usr-sbin/evsrc-check $(1)/usr/sbin/evsrc-check
	$(INSTALL_BIN) ./files/usr-sbin/mld-bsta-relink $(1)/usr/sbin/mld-bsta-relink
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-fdb-guard $(1)/usr/sbin/easymesh-fdb-guard
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-bh-rescue $(1)/usr/sbin/easymesh-bh-rescue
	$(INSTALL_BIN) ./files/usr-sbin/mld-config-check $(1)/usr/sbin/mld-config-check
	$(INSTALL_BIN) ./files/usr-sbin/mld-link-check $(1)/usr/sbin/mld-link-check
	$(INSTALL_BIN) ./files/usr-sbin/mld-report-check $(1)/usr/sbin/mld-report-check
	$(INSTALL_BIN) ./files/usr-sbin/mlo-backhaul-setup $(1)/usr/sbin/mlo-backhaul-setup
	$(INSTALL_BIN) ./files/usr-sbin/node-heartbeat $(1)/usr/sbin/node-heartbeat
	$(INSTALL_BIN) ./files/usr-sbin/mesh-name $(1)/usr/sbin/mesh-name
	$(INSTALL_BIN) ./files/usr-sbin/mesh-names-sync $(1)/usr/sbin/mesh-names-sync
	$(INSTALL_BIN) ./files/usr-sbin/hostapd-watch $(1)/usr/sbin/hostapd-watch
	$(INSTALL_BIN) ./files/usr-sbin/beacon-kick $(1)/usr/sbin/beacon-kick
	$(INSTALL_BIN) ./files/init.d/beacon-kick $(1)/etc/init.d/beacon-kick
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-linkstat $(1)/usr/sbin/easymesh-linkstat
	$(INSTALL_BIN) ./files/init.d/easymesh-linkstat $(1)/etc/init.d/easymesh-linkstat
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-linkstat-collect $(1)/usr/sbin/easymesh-linkstat-collect
	$(INSTALL_BIN) ./files/init.d/easymesh-linkstat-collect $(1)/etc/init.d/easymesh-linkstat-collect
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-ttlm-policy $(1)/usr/sbin/easymesh-ttlm-policy
	$(INSTALL_BIN) ./files/init.d/easymesh-ttlm-policy $(1)/etc/init.d/easymesh-ttlm-policy
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-card-check $(1)/usr/sbin/easymesh-card-check
	$(INSTALL_BIN) ./files/init.d/easymesh-card-check $(1)/etc/init.d/easymesh-card-check
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-gw-watch $(1)/usr/sbin/easymesh-gw-watch
	$(INSTALL_BIN) ./files/init.d/easymesh-gw-watch $(1)/etc/init.d/easymesh-gw-watch
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-parent-scan $(1)/usr/sbin/easymesh-parent-scan
	$(INSTALL_BIN) ./files/init.d/easymesh-parent-scan $(1)/etc/init.d/easymesh-parent-scan
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-bh-trial $(1)/usr/sbin/easymesh-bh-trial
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-parent-plan $(1)/usr/sbin/easymesh-parent-plan
	$(INSTALL_BIN) ./files/init.d/easymesh-parent-plan $(1)/etc/init.d/easymesh-parent-plan
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-dhcpguard $(1)/usr/sbin/easymesh-dhcpguard
	$(INSTALL_BIN) ./files/init.d/easymesh-dhcpguard $(1)/etc/init.d/easymesh-dhcpguard
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_DATA) ./files/hotplug/60-easymesh-dhcpguard $(1)/etc/hotplug.d/iface/60-easymesh-dhcpguard
	$(INSTALL_BIN) ./files/init.d/hostapd-watch $(1)/etc/init.d/hostapd-watch
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-logkeep $(1)/usr/sbin/easymesh-logkeep
	$(INSTALL_BIN) ./files/init.d/easymesh-logkeep $(1)/etc/init.d/easymesh-logkeep
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-logcap $(1)/usr/sbin/easymesh-logcap
	$(INSTALL_BIN) ./files/init.d/easymesh-logcap $(1)/etc/init.d/easymesh-logcap
	$(INSTALL_BIN) ./files/usr-sbin/wnm-enable $(1)/usr/sbin/wnm-enable
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-check $(1)/usr/sbin/easymesh-check
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-nightwatch $(1)/usr/sbin/easymesh-nightwatch
	$(INSTALL_BIN) ./files/usr-sbin/punct $(1)/usr/sbin/punct
	$(INSTALL_BIN) ./files/init.d/easymesh-nightwatch $(1)/etc/init.d/easymesh-nightwatch

	$(INSTALL_BIN) ./files/usr-sbin/bh-key-adopt $(1)/usr/sbin/bh-key-adopt
	$(INSTALL_BIN) ./files/usr-sbin/easymesh-soft-restart $(1)/usr/sbin/easymesh-soft-restart
	$(INSTALL_BIN) ./files/init.d/bh-key-adopt $(1)/etc/init.d/bh-key-adopt
	$(INSTALL_BIN) ./files/init.d/mld-bsta-bridge $(1)/etc/init.d/mld-bsta-bridge
	$(INSTALL_BIN) ./files/init.d/drop-legacy-fronthaul $(1)/etc/init.d/drop-legacy-fronthaul
	$(INSTALL_BIN) ./files/init.d/wifi-evmap $(1)/etc/init.d/wifi-evmap
	$(INSTALL_BIN) ./files/init.d/evsrc-check $(1)/etc/init.d/evsrc-check
	$(INSTALL_BIN) ./files/init.d/mld-bsta-relink $(1)/etc/init.d/mld-bsta-relink
	$(INSTALL_BIN) ./files/init.d/easymesh-fdb-guard $(1)/etc/init.d/easymesh-fdb-guard
	$(INSTALL_BIN) ./files/init.d/easymesh-bh-rescue $(1)/etc/init.d/easymesh-bh-rescue
	$(INSTALL_BIN) ./files/init.d/mld-config-check $(1)/etc/init.d/mld-config-check
	$(INSTALL_BIN) ./files/init.d/mld-link-check $(1)/etc/init.d/mld-link-check
	$(INSTALL_BIN) ./files/init.d/mld-report-check $(1)/etc/init.d/mld-report-check
	$(INSTALL_BIN) ./files/init.d/node-heartbeat $(1)/etc/init.d/node-heartbeat
	$(INSTALL_BIN) ./files/init.d/mesh-name $(1)/etc/init.d/mesh-name
	$(INSTALL_BIN) ./files/init.d/mesh-names-sync $(1)/etc/init.d/mesh-names-sync
	$(INSTALL_BIN) ./files/init.d/wnm-enable $(1)/etc/init.d/wnm-enable
	$(INSTALL_BIN) ./files/init.d/easymesh-check $(1)/etc/init.d/easymesh-check

	$(INSTALL_BIN) ./files/uci-defaults/88-easymesh-role-marker $(1)/etc/uci-defaults/88-easymesh-role-marker
	$(INSTALL_BIN) ./files/uci-defaults/94-easymesh-drop-phantom-bsta $(1)/etc/uci-defaults/94-easymesh-drop-phantom-bsta
	$(INSTALL_BIN) ./files/uci-defaults/96-easymesh-drop-disallow-profile $(1)/etc/uci-defaults/96-easymesh-drop-disallow-profile
	$(INSTALL_BIN) ./files/uci-defaults/97-mapc-db-keep $(1)/etc/uci-defaults/97-mapc-db-keep
endef

$(eval $(call BuildPackage,easymesh-wifi))
