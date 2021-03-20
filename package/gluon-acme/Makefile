include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-acme
PKG_VERSION:=1

include ../gluon.mk

define Package/gluon-acme
  TITLE:=Obtain LetsEncrypt Certificates in Gluon
  DEPENDS:=+uacme +libuhttpd-mbedtls +libustream-mbedtls
endef

$(eval $(call BuildPackageGluon,gluon-acme))
