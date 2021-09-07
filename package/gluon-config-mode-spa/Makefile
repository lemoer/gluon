# Copyright (C) 2021 Leonardo Moerlein <me at irrelefant.net>
# This is free software, licensed under the Apache 2.0 license.

include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-config-mode-spa
PKG_VERSION:=1

include ../gluon.mk

define Package/gluon-config-mode-spa
  TITLE:=Provides a Single Page Application to configure the gluon node
  DEPENDS:=+gluon-web +uhttpd +gluon-config-api-core
endef

$(eval $(call BuildPackageGluon,gluon-config-mode-spa))
