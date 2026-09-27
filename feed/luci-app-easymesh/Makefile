# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-easymesh
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

LUCI_TITLE:=EasyMesh R6 mesh management
LUCI_DESCRIPTION:=Web UI for the EasyMesh R6 mesh: topology, nodes, clients, health. Talks only to the easymesh ubus dictionary.
LUCI_DEPENDS:=+luci-base +easymesh-api

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
