# SPDX-License-Identifier: BSD-3-Clause
# Copyright (C) 2026 Petr Wozniak (WOZIWRT project)
include $(TOPDIR)/rules.mk

PKG_NAME:=easymesh-trace
PKG_VERSION:=0.1.0
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=Petr Wozniak <petr.wozniak@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/easymesh-trace
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=EasyMesh
  TITLE:=EasyMesh boot chain trace (debug builds only)
  DEPENDS:=+easymesh-wifi
  PKGARCH:=all
endef

define Package/easymesh-trace/description
  Makes the boot chain write down what it did, instead of us reading the
  sources afterwards and guessing.

  One line is inserted after the shebang of every shell script between
  power-on and a formed mesh - including /etc/rc.common, which covers every
  service on the box, and the netifd and hotplug paths that no init script
  lists. Each traced run records who started it (the whole parent chain), its
  arguments and environment, a full state snapshot before the body, a
  line-by-line trace of the body, the same snapshot after, and the difference
  between them. Everything lands in one file, in the order it happened, so a
  boot reads top to bottom.

  Written for the question this project could not answer any other way: which
  process writes a wrong value into /etc/config/wireless, and at what second.
  On 2026-08-19 it answered it in one boot - map_genconfig falls back to the
  factory MLD SSID whenever the fronthaul key is momentarily empty, which is
  exactly the window easymesh-role opens during onboarding.

  NOT for production images. The trace file runs to tens of megabytes per
  boot, tracing adds around half a second to every script in the chain, and
  the added delay can move the timing of the very races being hunted. Put it
  in a debug build, measure, take it back out. /etc/easymesh-trace.conf turns
  it down to nothing without an uninstall.
endef

define Package/easymesh-trace/conffiles
/etc/easymesh-trace.conf
endef

define Build/Compile
endef

define Package/easymesh-trace/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/share/easymesh $(1)/etc $(1)/etc/init.d $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/trace.sh $(1)/usr/share/easymesh/trace.sh
	$(INSTALL_BIN) ./files/easymesh-trace-install $(1)/usr/sbin/easymesh-trace-install
	$(INSTALL_CONF) ./files/easymesh-trace.conf $(1)/etc/easymesh-trace.conf
	$(INSTALL_BIN) ./files/init.d/easymesh-trace $(1)/etc/init.d/easymesh-trace
	$(INSTALL_BIN) ./files/uci-defaults/09-easymesh-trace $(1)/etc/uci-defaults/09-easymesh-trace
endef

define Package/easymesh-trace/prerm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0
# Take every hook back out before the library it points at disappears - a
# script sourcing a file that is gone costs a fork per run and looks like a
# mystery in six months.
[ -x /usr/sbin/easymesh-trace-install ] && /usr/sbin/easymesh-trace-install off >/dev/null 2>&1
exit 0
endef

$(eval $(call BuildPackage,easymesh-trace))
