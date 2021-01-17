#!/bin/sh

INCLUDE_ONLY=1
. /lib/netifd/proto/wireguard.sh

ensure_key_is_generated vpn
uci get network.vpn.private_key | /usr/bin/wg pubkey
