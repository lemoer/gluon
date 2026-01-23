include $(TOPDIR)/rules.mk

PKG_NAME:=wg-trace-delay-c
PKG_RELEASE:=18

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

PKG_BUILD_DEPENDS:=bpf-headers
include $(INCLUDE_DIR)/bpf.mk

define Package/wg-trace-delay-c
  SECTION:=net
  CATEGORY:=Network
  TITLE:=WireGuard encrypt latency tracer (C + eBPF)
	DEPENDS:=+libbpf $(BPF_DEPENDS)
endef

define Package/wg-trace-delay-c/description
 A small userspace + eBPF tool to trace WireGuard encryption latency.
endef

# Repo-Root relativ zum Package-Verzeichnis:
# openwrt/net/wg-trace-delay-c -> ../../.. = veth-batman
VETH_BATMAN_ROOT:=$(CURDIR)/../../..

define Build/Prepare
	$(call Build/Prepare/Default)
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
	$(CP) $(VETH_BATMAN_ROOT)/bpf/wg_trace_delay.bpf.c $(PKG_BUILD_DIR)/wg_trace_delay.bpf.c
	$(call CompileBPF,$(PKG_BUILD_DIR)/wg_trace_delay.bpf.c)
	# 2) Userspace-Binary mit der OpenWrt-Target-Toolchain bauen
	$(TARGET_CC) $(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include \
		-o $(PKG_BUILD_DIR)/wg_trace_delay_c \
		$(VETH_BATMAN_ROOT)/wg_trace_delay_c_src/main.c \
		-lbpf $(TARGET_LDFLAGS)
endef

define Package/wg-trace-delay-c/install
	$(INSTALL_DIR) $(1)/usr/sbin
	# Userspace-Binary aus dem Target-Build installieren
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wg_trace_delay_c $(1)/usr/sbin/wg_trace_delay_c
	$(INSTALL_DIR) $(1)/usr/sbin/bpf
	# BPF-Objekt aus dem Repo installieren
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/wg_trace_delay.bpf.o $(1)/usr/sbin/bpf/
endef

$(eval $(call BuildPackage,wg-trace-delay-c))
