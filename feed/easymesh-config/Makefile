# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
include $(TOPDIR)/rules.mk

PKG_NAME:=easymesh-config
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/easymesh-config
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=EasyMesh
  TITLE:=EasyMesh node configuration (role, safe defaults)
  DEPENDS:=+uci +easymesh-wifi
  PKGARCH:=all
endef

define Package/easymesh-config/description
  Turns a freshly installed node into a mesh member:

  easymesh-role  - one-shot role tool (controller or agent). A mesh has
                   exactly one controller; the choice is explicit because
                   nothing can infer which box the user meant to lead.

  Boot-time defaults, each guarding a failure this project actually hit:
    * a box with no mesh role runs neither daemon - otherwise map-agent
      builds its BSSes from factory sections and a brand-new router puts
      the mesh backhaul on the air before anyone has asked for a mesh;
    * the backhaul AP-MLD is declared before the agent generates its
      config - without it the MLD backhaul path is a silent no-op;
    * only the controller serves DHCP - a second server on the single L2
      domain hands clients itself as their gateway, which looks exactly
      like a broken radio;
    * only one process reads /proc/kmsg - logd and rsyslog's imklog race
      for every kernel message, and a logd that loses the race blocks for
      good, taking dropbear, netifd and hostapd down with it while the
      node still answers ping;
    * mlo-steerd stays installed but does not start by itself - it is a
      second steering brain, and its advertised TTLM disables a band for
      every client on the node based on the weakest one.

  All are idempotent and never override an explicit user setting.
endef

define Build/Compile
endef

define Package/easymesh-config/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/easymesh-role $(1)/usr/sbin/easymesh-role
	$(INSTALL_BIN) ./files/89-easymesh-quiet-until-role $(1)/etc/uci-defaults/89-easymesh-quiet-until-role
	$(INSTALL_BIN) ./files/90-easymesh-mld-backhaul $(1)/etc/uci-defaults/90-easymesh-mld-backhaul
	$(INSTALL_BIN) ./files/995-easymesh-dhcp-safe $(1)/etc/uci-defaults/995-easymesh-dhcp-safe
	$(INSTALL_BIN) ./files/92-easymesh-apk-feed $(1)/etc/uci-defaults/92-easymesh-apk-feed
	$(INSTALL_BIN) ./files/93-easymesh-single-kmsg-reader $(1)/etc/uci-defaults/93-easymesh-single-kmsg-reader
	$(INSTALL_BIN) ./files/94-easymesh-rsyslog-no-remote $(1)/etc/uci-defaults/94-easymesh-rsyslog-no-remote
	$(INSTALL_BIN) ./files/95-easymesh-mlo-steerd-off $(1)/etc/uci-defaults/95-easymesh-mlo-steerd-off
	$(INSTALL_BIN) ./files/96-easymesh-6g-backhaul-no-mbssid $(1)/etc/uci-defaults/96-easymesh-6g-backhaul-no-mbssid
	$(INSTALL_BIN) ./files/97-easymesh-stp-root-controller $(1)/etc/uci-defaults/97-easymesh-stp-root-controller
	$(INSTALL_BIN) ./files/98-easymesh-bh-no-inactivity-poll $(1)/etc/uci-defaults/98-easymesh-bh-no-inactivity-poll
endef

define Package/easymesh-config/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
cat <<'MSG'

  easymesh-config installed.

  Next: pick this node's role, then reboot.
      easymesh-role controller
      easymesh-role agent [controller-ip]

  The radios are configured once at boot; this stack does not
  reconfigure them at runtime, so the reboot is required.

MSG
exit 0
endef

$(eval $(call BuildPackage,easymesh-config))
