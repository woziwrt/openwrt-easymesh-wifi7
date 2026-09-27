#
# Copyright (C) 2020-2024 Iopsys
# Copyright (C) 2025 Genexis Sweden AB
#

include $(TOPDIR)/rules.mk

PKG_NAME:=wifimngr
PKG_VERSION:=21.0.5
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))

LOCAL_DEV=0
ifneq ($(LOCAL_DEV),1)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=cc93661d2be86ff04994335c322414d3958e8cba
PKG_SOURCE_URL:=https://dev.iopsys.eu/hal/wifimngr.git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)_$(PKG_SOURCE_VERSION).tar.xz
PKG_MIRROR_HASH:=skip
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=
PKG_MAINTAINER:=Anjan Chanda <anjan.chanda@genexis.eu>

PKG_CONFIG_DEPENDS := \
		     CONFIG_PACKAGE_libwifiutils \
		     CONFIG_PACKAGE_libwifi

PKG_BUILD_DEPENDS := libwifi

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

ifeq ($(CONFIG_WIFIMNGR_BUILD_TR181_PLUGIN),y)
include $(TOPDIR)/feeds/iopsys/bbfdm/bbfdm.mk
endif

define Package/wifimngr
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=WiFi status and configration utility
	DEPENDS:=+libwifiutils +libwifi +libnl-genl \
		 +libjson-c +libuci +libubox +libblobmsg-json +ubus
	DEPENDS+=+WIFIMNGR_BUILD_TR181_PLUGIN:libbbfdm-api \
		+WIFIMNGR_BUILD_TR181_PLUGIN:libbbfdm-ubus
endef

define Package/wifimngr/description
 This package can be used to configure and provide status about
 the WiFi modules through UBUS.
 It does this in an implementation agnostic manner through APIs
 exposed by the libwifi library.
endef

ifeq ($(LOCAL_DEV),1)
define Build/Prepare
  rsync -r --exclude=.* ~/git/wifimngr/ $(PKG_BUILD_DIR)/
endef
endif

ifeq ($(CONFIG_WIFIMNGR_CACHE_SCANRESULTS),y)
TARGET_CFLAGS += -DWIFI_CACHE_SCANRESULTS
endif

ifeq ($(CONFIG_WIFIMNGR_BUILD_TR181_PLUGIN),y)
CMAKE_OPTIONS += -DWIFIMNGR_BUILD_TR181_PLUGIN=ON
ifeq ($(CONFIG_WIFIMNGR_VENDOR_EXTENSIONS),y)
TARGET_CFLAGS += -DWIFIMNGR_VENDOR_EXTENSIONS
endif
endif

ifeq ($(CONFIG_WIFIMNGR_VENDOR_PREFIX),"")
CMAKE_OPTIONS += -DBBF_VENDOR_PREFIX:String="$(CONFIG_BBF_VENDOR_PREFIX)"
else
CMAKE_OPTIONS += -DBBF_VENDOR_PREFIX:String="$(CONFIG_WIFIMNGR_VENDOR_PREFIX)"
endif

define Package/wifimngr/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/wifimngr $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wifimngr $(1)/usr/sbin/
ifeq ($(CONFIG_WIFIMNGR_BUILD_TR181_PLUGIN),y)
	$(BBFDM_REGISTER_SERVICES) ./bbfdm_service.json $(1) $(PKG_NAME)
endif
endef

define Package/wifimngr/config
        source "$(SOURCE)/Config.in"
endef

$(eval $(call BuildPackage,wifimngr))
