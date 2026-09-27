#
# Copyright (C) 2020-2024 IOPSYS Software Solutions AB
# Copyright (C) 2025 Genexis AB
#

include $(TOPDIR)/rules.mk

PKG_NAME:=map-controller
PKG_VERSION:=6.5.0.18
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=c3937dc4cf6e4e59c7361326f042e56d24d700dd
PKG_MAINTAINER:=Jakob Olsson <jakob.olsson@genexis.eu>

LOCAL_DEV=0
ifneq ($(LOCAL_DEV),1)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://dev.iopsys.eu/multi-ap/map-controller
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)_$(PKG_SOURCE_VERSION).tar.xz
PKG_MIRROR_HASH:=skip
endif

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

PKG_CONFIG_DEPENDS:= \
	CONFIG_CONTROLLER_USE_LIBDPP \
	CONFIG_CONTROLLER_ZEROTOUCH_DPP \
	CONFIG_CONTROLLER_EASYMESH_VERSION \
	CONFIG_CONTROLLER_IEEE1905_ETH_MEDIA_EXTENSION \
	CONFIG_CONTROLLER_SYNC_DYNAMIC_CNTLR_CONFIG \
	CONFIG_CONTROLLER_EASYMESH_VENDOR_EXT \
	CONFIG_CONTROLLER_EASYMESH_VENDOR_EXT_OUI \
	CONFIG_CONTROLLER_PROVISION_DISABLED_AP \
	CONFIG_CONTROLLER_PROVISION_BRIDGE \
	CONFIG_CONTROLLER_PROPAGATE_PROBE_REQ

include $(INCLUDE_DIR)/package.mk

define Package/map-controller
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=WiFi Multi-AP Controller (supporting EasyMesh R6)
  DEPENDS:=+libuci +libubox +ubus +libeasy +libwifiutils +libieee1905 +ieee1905 +ieee1905-map-plugin \
	   +libsqlite3 \
	   +CONTROLLER_USE_LIBDPP:libdpp
endef

ifeq ($(CONFIG_CONTROLLER_USE_LIBDPP),y)
  TARGET_CFLAGS += -DUSE_LIBDPP
endif

ifeq ($(CONFIG_CONTROLLER_ZEROTOUCH_DPP),y)
  TARGET_CFLAGS += -DZEROTOUCH_DPP
endif

ifeq ($(CONFIG_CONTROLLER_IEEE1905_ETH_MEDIA_EXTENSION),y)
TARGET_CFLAGS += -DIEEE1905_ETH_MEDIA_EXTENSION
endif

define Package/map-controller/description
 This package provides WiFi MultiAP Controller as per the EasyMesh-R2 specs.
endef

define Package/map-controller/config
	source "$(SOURCE)/Config.in"
endef

TARGET_CFLAGS += \
	-Wno-error=deprecated-declarations \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/libnl3 \
	-D_GNU_SOURCE

MAKE_PATH:=src

TARGET_CFLAGS += -DEASYMESH_VERSION=$(CONFIG_CONTROLLER_EASYMESH_VERSION)

ifeq ($(CONFIG_CONTROLLER_SYNC_DYNAMIC_CNTLR_CONFIG),y)
TARGET_CFLAGS += -DCONTROLLER_SYNC_DYNAMIC_CNTLR_CONFIG
endif

ifeq ($(CONFIG_CONTROLLER_EASYMESH_VENDOR_EXT),y)
TARGET_CFLAGS += -DEASYMESH_VENDOR_EXT_OUI=$(CONFIG_CONTROLLER_EASYMESH_VENDOR_EXT_OUI)
TARGET_CFLAGS += -DEASYMESH_VENDOR_EXT
ifeq ($(CONFIG_CONTROLLER_PROVISION_DISABLED_AP),y)
TARGET_CFLAGS += -DPROVISION_DISABLED_AP
endif
ifeq ($(CONFIG_CONTROLLER_PROVISION_BRIDGE),y)
TARGET_CFLAGS += -DPROVISION_BRIDGE
endif
endif

ifeq ($(CONFIG_CONTROLLER_PROPAGATE_PROBE_REQ),y)
TARGET_CFLAGS += -DPROPAGATE_PROBE_REQ
endif

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/map-controller
	$(INSTALL_DIR) $(1)/usr/include/map-controller/utils
	$(CP) $(PKG_BUILD_DIR)/src/wifi_dataelements.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/cntlr_commands_impl.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/cntlr_commands.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/cntlr_apis.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/cntlr_plugin.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/wifi_opclass.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/steer_module.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/timer.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/timer_impl.h $(1)/usr/include/map-controller
	$(CP) $(PKG_BUILD_DIR)/src/utils/debug.h $(1)/usr/include/map-controller/utils
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/src/libcntlr-apis.so $(1)/usr/lib
endef

define Package/map-controller/install
	$(INSTALL_DIR) $(1)/etc
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/mapcontroller $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/usr/lib/mapcontroller
	$(CP) $(PKG_BUILD_DIR)/src/libcntlr-apis.so $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/src/plugins/steer/rcpi/rcpi.so $(1)/usr/lib/mapcontroller/rcpi.so
endef

ifeq ($(LOCAL_DEV),1)
define Build/Prepare
        rsync -r --exclude=.* ~/git/map-controller/ $(PKG_BUILD_DIR)/
endef
endif

$(eval $(call BuildPackage,map-controller))
