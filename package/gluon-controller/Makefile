include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-controller
PKG_VERSION:=1

include ../gluon.mk

define Package/gluon-controller
  TITLE:=Package to control gluon
  DEPENDS:=+gluon-web +uhttpd +sse-multiplex
endef

define Package/gluon-controller/install
	$(Gluon/Build/Install)

	sass --sourcemap=none -C -t compressed ./sass/controller.scss $(1)/lib/gluon/controller/www/static/controller.css

endef

PKG_CONFIG_DEPENDS += CONFIG_GLUON_MINIFY

$(eval $(call BuildPackageGluon,gluon-controller))
