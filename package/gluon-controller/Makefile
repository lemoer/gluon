include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-controller
PKG_VERSION:=1

include ../gluon.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/gluon-controller
  TITLE:=Package to control gluon
  DEPENDS:=+gluon-web +uhttpd +sse-multiplex +rpcd +libuclient +libuci +libjson-c +autossh
endef

define Package/gluon-controller/install
	$(Gluon/Build/Install)

	$(LN) /lib/gluon/web/view/{error,model} $(1)/lib/gluon/controller/view/
	$(LN) /lib/gluon/web/www/static/gluon-web-model.js $(1)/lib/gluon/controller/www/static/

	$(INSTALL_DIR) $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/gluon-controller-update-nodes $(1)/usr/bin/
endef

PKG_CONFIG_DEPENDS += CONFIG_GLUON_MINIFY

$(eval $(call BuildPackageGluon,gluon-controller))
