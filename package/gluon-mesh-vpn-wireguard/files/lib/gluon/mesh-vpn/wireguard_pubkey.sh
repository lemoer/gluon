#!/bin/sh

INCLUDE_ONLY=1
. /lib/netifd/proto/wireguard.sh

ensure_key_is_generated vpn
iface="$(lua -e "vpn = require 'gluon.mesh-vpn'; print(vpn.get_interface())")"
uci get "network.$iface.private_key" | /usr/bin/wg pubkey
