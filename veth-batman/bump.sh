#!/bin/sh

set -e

current=$(grep PKG_RELEASE openwrt/net/wg-trace-delay-c/Makefile | cut -d '=' -f2 | tr -d ' ')
next=$((current + 1))

sed -i "s/PKG_RELEASE:=${current}/PKG_RELEASE:=${next}/" openwrt/net/wg-trace-delay-c/Makefile