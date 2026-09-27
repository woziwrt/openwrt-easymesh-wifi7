#
# Copyright (C) 2019-2024 Iopsys
# Copyright (C) 2025 Genexis Sweden AB
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libwifi
PKG_VERSION:=7.25.7
PKG_RELEASE:=$(shell echo $$((100 + $$(git rev-list --count HEAD -- . 2>/dev/null || echo 0))))

LOCAL_DEV=0
ifneq ($(LOCAL_DEV),1)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=0451527447f27c655c37b1953174c26e944c79a0
PKG_SOURCE_URL:=https://dev.iopsys.eu/hal/libwifi.git
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)_$(PKG_SOURCE_VERSION).tar.xz
PKG_MIRROR_HASH:=skip
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_LICENSE:=LGPL-2.1-only
PKG_LICENSE_FILES:=
PKG_MAINTAINER:=Anjan Chanda <anjan.chanda@genexis.eu>

MAKE_VERBOSE := 1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/cmake.mk

ifeq ($(CONFIG_TARGET_brcmbca),y)
  TARGET_PLATFORM=BROADCOM
  TARGET_WIFI_TYPE=BROADCOM
  CONFIG_ID=$(SUBTARGET:bcm%=BCM%)
  CHIP_ID=$(CONFIG_ID:BCM9%=%)
  TARGET_CFLAGS +=-DIOPSYS_BROADCOM -DCHIP_$(CHIP_ID) -DCONFIG_$(CONFIG_ID) \
	-I$(STAGING_DIR)/usr/include/bcm963xx/bcmdrivers/opensource/include/bcm963xx \
	-I$(STAGING_DIR)/usr/include/bcm963xx/userspace/public/include
else ifeq ($(CONFIG_TARGET_x86),y)
  TARGET_PLATFORM=TEST
  TARGET_WIFI_TYPE=TEST
  TARGET_CFLAGS +=-DIOPSYS_TEST
else ifeq ($(CONFIG_TARGET_armvirt),y)
  TARGET_PLATFORM=TEST
  TARGET_WIFI_TYPE=TEST
  TARGET_CFLAGS +=-DIOPSYS_TEST
else ifeq ($(CONFIG_TARGET_airoha),y)
  TARGET_PLATFORM=ECONET
  TARGET_WIFI_TYPE=MEDIATEK
  TARGET_CFLAGS +=-DIOPSYS_ECONET -I$(LINUX_DIR)/include/uapi/linux/mtk_nl80211_inc
  ifeq ($(CONFIG_TARGET_airoha_an7581),y)
    TARGET_CFLAGS +=-DCONFIG_MTK
  endif
else ifeq ($(CONFIG_TARGET_mediatek),y)
  TARGET_PLATFORM=MEDIATEK
  TARGET_WIFI_TYPE=MAC80211
  ifeq ($(CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_cx750),y)
    TARGET_WIFI_TYPE=MEDIATEK
    TARGET_CFLAGS +=-DCONFIG_MTK -I$(LINUX_DIR)/include/uapi/linux/mtk_nl80211_inc
  else ifeq ($(CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_mediatek_mt7987a-spim-nand-an8801sb),y)
    TARGET_WIFI_TYPE=MEDIATEK
    TARGET_CFLAGS +=-DCONFIG_MTK -I$(LINUX_DIR)/include/uapi/linux/mtk_nl80211_inc
  endif
else ifeq ($(CONFIG_TARGET_ipq95xx),y)
  TARGET_PLATFORM=IPQ95XX
  TARGET_WIFI_TYPE=QUALCOMM
  TARGET_CFLAGS +=-DIPQ95XX
else ifeq ($(CONFIG_TARGET_ipq53xx),y)
  TARGET_PLATFORM=IPQ53XX
  TARGET_WIFI_TYPE=QUALCOMM
  TARGET_CFLAGS +=-DIPQ53XX
else
  $(info Unexpected CONFIG_TARGET, use default MAC80211)
  TARGET_PLATFORM=MAC80211
  TARGET_CFLAGS +=-DIOPSYS_MAC80211
endif

ifneq ($(CONFIG_PACKAGE_kmod-mt7915e_en7523),)
  TARGET_CFLAGS +=-DMT7915_VENDOR_EXT
endif

PKG_BUILD_DEPENDS:=PACKAGE_kmod-mt7915e_en7523:mt76_en7523

ifneq ($(CONFIG_PACKAGE_libwifi),)
  CMAKE_OPTIONS +=-DHAS_WIFI=ON
endif

ifeq ($(CONFIG_LIBWIFI_USE_CTRL_IFACE),y)
  TARGET_CFLAGS +=-DLIBWIFI_USE_CTRL_IFACE
endif

ifeq ($(CONFIG_LIBWIFI_SKIP_PROBES),y)
  TARGET_CFLAGS +=-DLIBWIFI_BRCM_SKIP_PROBES
endif


CMAKE_OPTIONS += -DPLATFORM=$(TARGET_PLATFORM) -DWIFI_TYPE=$(TARGET_WIFI_TYPE)

ifeq ($(LOCAL_DEV),1)
define Build/Prepare
	rsync -r --exclude=.* ~/git/libwifi/ $(PKG_BUILD_DIR)/
endef
endif

define Package/libwifiutils
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:= WiFi utility library (libwifiutils.so)
	DEPENDS+=+libnl +libnl-route +libeasy +libopenssl
endef

define Package/libwifiutils/description
	Library provides WiFi utility functions
endef

define Package/libwifi
	SECTION:=libs
	CATEGORY:=Libraries
	TITLE:= WiFi HAL library (libwifi-7.so.m)
	DEPENDS+=+libnl +libnl-route +libeasy +libwifiutils +TARGET_brcmbca:bcm963xx-bsp
endef

define Package/libwifi/description
	Library provides WiFi HAL APIs
endef

define Build/InstallDev/libwifiutils
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libwifiutils/wifidefs.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/libwifiutils/wifiutils.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/libwifiutils/libwifiutils*.so* $(1)/usr/lib/
endef

define Package/libwifiutils/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libwifiutils/libwifiutils*.so* $(1)/usr/lib/
endef

define Package/libwifi/config
  if PACKAGE_libwifi
	config LIBWIFI_DEBUG
		depends on PACKAGE_libwifi
		bool "Enable debugging in libwifi"
		default n

	config LIBWIFI_USE_CTRL_IFACE
		bool "Create UNIX sockets to interface with hostapd/wpa_supplicant"
		default y

	config LIBWIFI_SKIP_PROBES
		bool "Don't create probe-req events"
		default y

  endif
endef

define Build/InstallDev/libwifi
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libwifi/wifiops.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/libwifi/wifi.h $(1)/usr/include/
	$(CP) $(PKG_BUILD_DIR)/libwifi/libwifi-7*.so* $(1)/usr/lib/
endef


define Build/InstallDev
	$(call Build/InstallDev/libwifiutils,$(1),$(2))
ifneq ($(CONFIG_PACKAGE_libwifi),)
	$(call Build/InstallDev/libwifi,$(1),$(2))
endif
endef

define Package/libwifi/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libwifi/libwifi-7*.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libwifiutils))
$(eval $(call BuildPackage,libwifi))
