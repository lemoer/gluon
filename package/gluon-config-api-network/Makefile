# Copyright (C) 2023 Leonardo Moerlein <me at irrelefant.net>
# This is free software, licensed under the Apache 2.0 license.

include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-config-api-network
PKG_VERSION:=1

include ../gluon.mk

define Package/gluon-config-api-network
  TITLE:=Gluon-config-api module for network port configuration
  DEPENDS:=+gluon-config-api-core +gluon-client-bridge
endef

$(eval $(call BuildPackageGluon,gluon-config-api-network))
