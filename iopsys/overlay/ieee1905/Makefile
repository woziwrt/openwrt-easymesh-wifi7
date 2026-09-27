#
# Copyright (C) 2020-2024 IOPSYS Software Solutions AB
# Copyright (C) 2025-2026 Genexis Sweden AB
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ieee1905
PKG_VERSION:=8.9.13
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))

LOCAL_DEV=0
ifneq ($(LOCAL_DEV),1)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=cd02073ab1b71ea699719945a14c0e77baf53b6e
PKG_SOURCE_URL:=https://dev.iopsys.eu/multi-ap/ieee1905.git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)_$(PKG_SOURCE_VERSION).tar.xz
PKG_MIRROR_HASH:=skip
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_MAINTAINER:=Anjan Chanda <anjan.chanda@iopsys.eu>
PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

PKG_CONFIG_DEPENDS:= \
	CONFIG_IEEE1905_BUILD_TR181_PLUGIN \
	CONFIG_IEEE1905_PLATFORM_HAS_WIFI \
	CONFIG_IEEE1905_CMDU_SA_IS_ALMAC \
	CONFIG_IEEE1905_WIFI_EASYMESH \
	CONFIG_IEEE1905_CMDU_FRAGMENT_TLV_BOUNDARY \
	CONFIG_IEEE1905_EXTENSION_ALLOWED \
	CONFIG_IEEE1905_ETH_MEDIA_EXTENSION \
	CONFIG_BBF_VENDOR_PREFIX

include $(INCLUDE_DIR)/package.mk

ifeq ($(CONFIG_IEEE1905_BUILD_TR181_PLUGIN),y)
include $(TOPDIR)/feeds/iopsys/bbfdm/bbfdm.mk
endif

define Package/ieee1905/Default
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=IEEE-1905.1 stack
endef

define Package/ieee1905/config
  source "$(SOURCE)/Config.in"
endef

define Package/libieee1905
  $(call Package/ieee1905/Default)
  TITLE:=libieee1905.so (library for CMDU and TLV handling)
  DEPENDS= +libubox +libuci +libubus +libeasy +libnl-genl \
	   +libjson-c +libblobmsg-json +libwifiutils \
	   +iputils-arping
endef

define Package/ieee1905
  $(call Package/ieee1905/Default)
  TITLE:=ieee1905d (daemon implementing 1905.1 and provides cli)
  DEPENDS= +libubox +libuci +libubus +libeasy +libnl-genl \
	   +libjson-c +libblobmsg-json +ubus +libpthread \
	   +libieee1905 +IEEE1905_PLATFORM_HAS_WIFI:libwifi \
	   +libwifiutils +iputils-arping
  DEPENDS+=+IEEE1905_BUILD_TR181_PLUGIN:libbbfdm-api \
	   +IEEE1905_BUILD_TR181_PLUGIN:libbbfdm-ubus \
	   +IEEE1905_BUILD_TR181_PLUGIN:dm-service
endef

include $(wildcard plugins/*.mk)

define Package/ieee1905/description
 This package provides IEEE Std 1905.1 stack.
endef

define Package/libieee1905/description
 This package provides library functions for IEEE Std 1905.1 stack.
endef

plugins := \
	$(if $(CONFIG_PACKAGE_ieee1905-map-plugin),map) \
	$(if $(CONFIG_PACKAGE_ieee1905-snoop-plugin),snoop) \
	$(if $(CONFIG_PACKAGE_ieee1905-topology-plugin),topology)


ppkg:=$(patsubst plugins/%.mk,ieee1905-%-plugin,$(wildcard plugins/*.mk))


TARGET_CFLAGS += \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/libnl3 \
	-D_GNU_SOURCE

ifeq ($(CONFIG_IEEE1905_PLATFORM_HAS_WIFI),y)
TARGET_CFLAGS += -DHAS_WIFI
endif

ifeq ($(CONFIG_IEEE1905_CMDU_SA_IS_ALMAC),y)
TARGET_CFLAGS += -DCMDU_SA_IS_ALMAC
endif

ifeq ($(CONFIG_IEEE1905_WIFI_EASYMESH),y)
TARGET_CFLAGS += -DWIFI_EASYMESH
endif

ifeq ($(CONFIG_IEEE1905_CMDU_FRAGMENT_TLV_BOUNDARY),y)
TARGET_CFLAGS += -DIEEE1905_CMDU_FRAGMENT_TLV_BOUNDARY
endif

ifeq ($(CONFIG_IEEE1905_EXTENSION_ALLOWED),y)
TARGET_CFLAGS += -DEXTENSION_ALLOWED
endif

TARGET_CFLAGS += -DHAS_UBUS

ifeq ($(CONFIG_IEEE1905_BUILD_TR181_PLUGIN),y)
TARGET_CFLAGS += -DBUILD_TR181_PLUGIN
TARGET_CFLAGS += -DBBF_VENDOR_PREFIX=\\\"$(CONFIG_BBF_VENDOR_PREFIX)\\\"
endif

ifeq ($(CONFIG_IEEE1905_ETH_MEDIA_EXTENSION),y)
TARGET_CFLAGS += -DETH_MEDIA_EXTENSION
endif

MAKE_FLAGS += \
	extmod_subdirs="$(patsubst %,extensions/%,$(plugins))"

MAKE_PATH:=src


define Package/ieee1905/install
	$(CP) ./files/etc $(1)/
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/lib/ieee1905
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/ieee1905d $(1)/usr/sbin/
ifeq ($(CONFIG_IEEE1905_BUILD_TR181_PLUGIN),y)
	$(BBFDM_REGISTER_SERVICES) ./bbfdm_service.json $(1) $(PKG_NAME)
	$(BBFDM_INSTALL_MS_DM) $(PKG_BUILD_DIR)/tr181/ieee1905dm.so $(1) $(PKG_NAME)
endif
endef

define Package/libieee1905/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/src/libieee1905.so $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/src/libmidgen.so $(1)/usr/lib/
endef

define Build/InstallDev/libieee1905
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/lib/ieee1905
	$(CP) $(PKG_BUILD_DIR)/src/cmdu.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/cmdu_ackq.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/1905_tlvs.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/i1905_wsc.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/timer_impl.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/i1905_extension.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/src/libmidgen.so $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/src/libieee1905.so $(1)/usr/lib/
endef

define Build/InstallDev
	$(call Build/InstallDev/libieee1905,$(1),$(2))
	$(foreach p,$(ppkg),$(call Build/InstallDev/$(p),$(1),$(2)))
endef

ifeq ($(LOCAL_DEV),1)
define Build/Prepare
        rsync -r --exclude=.* ~/git/ieee1905/ $(PKG_BUILD_DIR)/
endef
endif

$(eval $(call BuildPackage,ieee1905))
$(eval $(call BuildPackage,libieee1905))
$(eval $(foreach p,$(ppkg),$(call BuildPackage,$(p))))
