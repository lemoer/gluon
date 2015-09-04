include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-announce
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/gluon-announce
  SECTION:=gluon
  CATEGORY:=Gluon
  DEPENDS:=+gluon-core +luci-lib-jsonc +lua-ethtool-stats
  TITLE:=Lua scripts announcing various information
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

TARGET_CFLAGS += $(FPIC)

define Build/Compile
	CFLAGS="$(TARGET_CFLAGS)" CPPFLAGS="$(TARGET_CPPFLAGS)" $(MAKE) -C $(PKG_BUILD_DIR) $(TARGET_CONFIGURE_OPTS)
endef

define Package/gluon-announce/install
	$(CP) ./files/* $(1)/
	mkdir -p $(1)/usr/lib/lua/gluon
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/announce.so $(1)/usr/lib/lua/gluon/
endef

$(eval $(call BuildPackage,gluon-announce))
