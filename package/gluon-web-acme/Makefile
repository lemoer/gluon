# Copyright (C) 2021 Leonardo Mörlein <me at irrelefant.net>
# This is free software, licensed under the Apache 2.0 license.

include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-web-acme
PKG_VERSION:=1
PKG_RELEASE:=1

include ../gluon.mk

define Package/gluon-web-acme
  TITLE:=gluon-web module to configure letsencrypt certificates
  DEPENDS:=+gluon-web-admin +gluon-acme
endef

$(eval $(call BuildPackageGluon,gluon-web-acme))
