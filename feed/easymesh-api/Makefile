# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#

include $(TOPDIR)/rules.mk

PKG_NAME:=easymesh-api
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/easymesh-api
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=EasyMesh
  TITLE:=EasyMesh read-only ubus API (rpcd dictionary)
  DEPENDS:=+rpcd +sqlite3-cli +jsonfilter +easymesh-core
  PKGARCH:=all
endef

define Package/easymesh-api/description
 One command dictionary over the controller SQLite DB: topology, nodes,
 clients, health, client history. The mesh web UI and any script talk to
 this instead of raw sqlite. Read-only by design.
endef

define Build/Compile
endef

define Package/easymesh-api/install
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/easymesh $(1)/usr/libexec/rpcd/easymesh
	$(INSTALL_BIN) ./files/easymesh-wps-join $(1)/usr/libexec/easymesh-wps-join
	$(INSTALL_BIN) ./files/easymesh-dhcp-probe $(1)/usr/libexec/easymesh-dhcp-probe
	$(INSTALL_DIR) $(1)/etc/rc.wps
	$(INSTALL_BIN) ./files/30-easymesh $(1)/etc/rc.wps/30-easymesh
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/easymesh-led $(1)/usr/sbin/easymesh-led
	$(INSTALL_BIN) ./files/easymesh-dhcp-guard $(1)/usr/sbin/easymesh-dhcp-guard
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/wps-join-resume.init $(1)/etc/init.d/wps-join-resume
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/95-easymesh-button $(1)/etc/uci-defaults/95-easymesh-button
endef

define Package/easymesh-api/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || /etc/init.d/rpcd restart
exit 0
endef

$(eval $(call BuildPackage,easymesh-api))
