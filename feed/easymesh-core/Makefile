# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#

include $(TOPDIR)/rules.mk

PKG_NAME:=easymesh-core
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/easymesh-core
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=EasyMesh
  TITLE:=EasyMesh core - database, identity and system access
  DEPENDS:=+sqlite3-cli
  PKGARCH:=all
endef

define Package/easymesh-core/description
 The three things every EasyMesh script needs and no script should carry its
 own copy of: reading the controller database, telling one box from another,
 and asking what this box currently is.

 Split out of the easymesh rpcd dictionary on 2026-09-05. It was a 2415-line
 file that was at once the UI backend, the mesh logic and the system adapter;
 these 160 lines were the part every other part had to reach into. The cut was
 measured, not designed: the ten functions here are exactly those the read side
 and the write side both used, they call nothing above them, and the rest of
 that file calls them sixty times.

 The boundary is held by DEPENDS, so a caller that forgets it fails to build.
 That is deliberate: this project has buried ten structures that were kept by
 agreement instead, and the longest-lived of them lasted 24 hours.
endef

define Build/Compile
endef

define Package/easymesh-core/install
	$(INSTALL_DIR) $(1)/usr/share/easymesh
	$(INSTALL_DATA) ./files/usr-share/db.sh $(1)/usr/share/easymesh/db.sh
	$(INSTALL_DATA) ./files/usr-share/names.sh $(1)/usr/share/easymesh/names.sh
	$(INSTALL_DATA) ./files/usr-share/sys.sh $(1)/usr/share/easymesh/sys.sh
endef

$(eval $(call BuildPackage,easymesh-core))
