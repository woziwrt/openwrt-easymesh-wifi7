# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
include $(TOPDIR)/rules.mk

PKG_NAME:=easymesh-mesh
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/easymesh-mesh
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=EasyMesh
  TITLE:=EasyMesh mesh layer (shared gateway, node roles)
  DEPENDS:=+ubus +uci
endef

define Package/easymesh-mesh/description
  L3 layer on top of the EasyMesh L2 mesh:

  mesh-gwd  - shared-gateway daemon. The node that has a working uplink
              claims a virtual gateway address on the bridge and installs
              the default route; every other node routes through it.
              Moving the ISP cable to another node moves the gateway with
              it, with clients keeping the same gateway address throughout.
              Hardware-verified failover in the 20-25 s range.

  mesh-role - one-shot role tool: makes a node the gateway (DHCP/DNS/NAT)
              or a plain AP pointing at a gateway. Idempotent, with a
              dry-run mode.
endef

define Build/Compile
endef

define Package/easymesh-mesh/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/init.d
	$(INSTALL_BIN) ./files/mesh-gwd $(1)/usr/sbin/mesh-gwd
	$(INSTALL_BIN) ./files/mesh-role $(1)/usr/sbin/mesh-role
	$(INSTALL_BIN) ./files/mesh-gwd.init $(1)/etc/init.d/mesh-gwd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/ntp
	$(INSTALL_BIN) ./files/ntp-hotplug $(1)/etc/hotplug.d/ntp/50-easymesh-clock-synced
endef

$(eval $(call BuildPackage,easymesh-mesh))
