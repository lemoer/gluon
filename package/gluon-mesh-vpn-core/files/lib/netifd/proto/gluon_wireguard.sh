#!/bin/sh

PROTO_DEBUG=1

. /lib/functions.sh
. ../netifd-proto.sh
init_proto "$@"

WG=/usr/bin/wg

proto_gluon_wireguard_init_config() {
	#no_device=1
	#available=1
	proto_config_add_int index
	proto_config_add_int mtu
}

interface_linklocal_from_wg_public_key() {
	# We generate a predictable v6 address
	local macaddr="$(printf "%s" "$1"|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')"
	local oldIFS="$IFS"; IFS=':';
	# shellcheck disable=SC2086
	set -- $macaddr; IFS="$oldIFS"
	echo "fe80::$1$2:$3ff:fe$4:$5$6"
}

proto_gluon_wireguard_setup() {
	local config="$1"
	local ifname="$2"

	local index mtu
	json_get_vars index mtu

	local public_key="$(/lib/gluon/mesh-vpn/wireguard_pubkey.sh)"

	# The wireguard proto itself can not be moved here, as the proto does not
	# allow add_dynamic.

	## Add IP

	proto_add_host_dependency "$config" '' "$ifname"
	proto_init_update "$ifname" 1
	proto_add_data
	json_add_string zone 'wired_mesh'
	proto_close_data
	proto_add_ipv6_address "$(interface_linklocal_from_wg_public_key "$public_key")" "128"
	proto_send_update "$ifname"

	## wgpeerselector

	json_init
	json_add_string name "${ifname}_peerselector"
	json_add_string ifname "$ifname"
	json_add_string proto 'wgpeerselector'
	json_add_string unix_group 'gluon-mesh-vpn'
	json_add_boolean transitive 1
	json_close_object
	ubus call network add_dynamic "$(json_dump)"

	## wired

	json_init
	json_add_string name "vpn_wired"
	json_add_string proto "gluon_wired"
	json_add_string ifname "$ifname"
	json_add_int index "$index"
	json_add_boolean transitive 1
	json_add_boolean add_vxlan_layer 1
	json_add_int mtu "$mtu"
	json_add_boolean fixed_mtu 1
	json_add_string vxpeer6addr 'fe80::1'
	json_close_object
	ubus call network add_dynamic "$(json_dump)"

	proto_init_update "$ifname" 1
	proto_send_update "$config"
}

proto_gluon_wireguard_teardown() {
	local config="$1"

	proto_init_update "*" 0
	proto_send_update "$config"
}

add_protocol gluon_wireguard
