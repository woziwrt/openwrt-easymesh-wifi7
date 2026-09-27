#
# Copyright (C) 2025 Genexis Sweden AB
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libeasy
PKG_VERSION:=7.5.1
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))

LOCAL_DEV=0
ifneq ($(LOCAL_DEV),1)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=b981f7e1bd51f66041cd0c25d15af74ae1e3bc75
PKG_SOURCE_URL:=https://dev.iopsys.eu/hal/libeasy.git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)_$(PKG_SOURCE_VERSION).tar.xz
PKG_MIRROR_HASH:=skip
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_LICENSE:=LGPL-2.1-only
PKG_LICENSE_FILES:=
PKG_MAINTAINER:=Anjan Chanda <anjan.chanda@genexis.eu>

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

ifeq ($(LOCAL_DEV),1)
define Build/Prepare
	rsync -r --exclude=.* ~/git/libeasy/ $(PKG_BUILD_DIR)/
endef
endif

define Package/libeasy
  SECTION:=libs
  CATEGORY:=Libraries
  SUBMENU:=IOPSYS HAL libs
  MENU:=1
  TITLE:= Common helper library (libeasy)
  DEPENDS+=+libnl +libnl-route +libopenssl
endef

define Package/libeasy/description
  This package provides libeasy.so for common utility functions.
endef

define Build/InstallDev/libeasy
	$(INSTALL_DIR) $(1)/usr/include/easy
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/easy.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/event.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/utils.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/bufutil.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/cryptutil.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/ecc_cryptutil.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/if_utils.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/debug.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/hlist.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/timestamp.h $(1)/usr/include/easy/
	$(CP) $(PKG_BUILD_DIR)/libeasy*.so* $(1)/usr/lib/
endef

define Build/InstallDev
	$(call Build/InstallDev/cmake,$(1))
	$(call Build/InstallDev/libeasy,$(1),$(2))
endef

define Package/libeasy/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libeasy*.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libeasy))
