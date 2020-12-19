#!/bin/sh

. /lib/functions.sh
. ../netifd-proto.sh
init_proto "$@"

proto_gluon_wired_init_config() {
        proto_config_add_boolean transitive
        proto_config_add_int index
        proto_config_add_string vxpeer6addr
        proto_config_add_boolean is_tunnel
}

xor2() {
        echo -n "${1:0:1}"
        echo -n "${1:1:1}" | tr '0123456789abcdef' '23016745ab89efcd'
}

is_layer3_device () {
        local addrlen="$(cat "/sys/class/net/$1/addr_len")"
        test "$addrlen" -eq 0
}

# shellcheck disable=SC2086
interface_linklocal() {
        if is_layer3_device "$1"; then
                # this is probably a layer 3 device
                ubus call "network.interface.$1" status  |  \
                        jsonfilter -e '@["ipv6-address"][*].address' | grep -e '^fe[89ab]' | head -n 1
                return
        fi

        local macaddr="$(ubus call network.device status '{"name": "'"$1"'"}' | jsonfilter -e '@.macaddr')"
        local oldIFS="$IFS"; IFS=':'; set -- $macaddr; IFS="$oldIFS"

        echo "fe80::$(xor2 "$1")$2:$3ff:fe$4:$5$6"
}

proto_gluon_wired_setup() {
        local config="$1"
        local ifname="$2"

        local meshif="$config"

        local transitive index vxpeer6addr is_tunnel
        json_get_vars transitive index vxpeer6addr is_tunnel

        ( proto_add_host_dependency "$config" '' "$ifname" )

        # default args
        [ -z "$is_tunnel" ] && is_tunnel=0
        [ -z "$vxpeer6addr" ] && vxpeer6addr='ff02::15c'

        if [ "$is_tunnel" -eq 1 ] && is_layer3_device "$ifname"; then
                local vxlan=true
        elif [ "$is_tunnel" -eq 1 ]; then
                local vxlan=false
        else
                local vxlan="$(lua -e 'print(require("gluon.site").mesh.vxlan(true))')"
        fi

        proto_init_update "$ifname" 1
        proto_send_update "$config"

        if [ "$vxlan" = 'true' ]; then
                meshif="vx_$config"

                json_init
                json_add_string name "$meshif"
                [ -n "$index" ] && json_add_string macaddr "$(lua -e "print(require('gluon.util').generate_mac($index))")"
                json_add_string proto 'vxlan6'
                json_add_string tunlink "$config"
                # ip6addr (the lower interface ip6) is used by the vxlan.sh proto
                json_add_string ip6addr "$(interface_linklocal "$ifname")"
                json_add_string peer6addr "$vxpeer6addr"
                json_add_int vid "$(lua -e 'print(tonumber(require("gluon.util").domain_seed_bytes("gluon-mesh-vxlan", 3), 16))')"
                json_add_boolean rxcsum '0'
                json_add_boolean txcsum '0'
                json_close_object
                ubus call network add_dynamic "$(json_dump)"
        fi

        json_init
        json_add_string name "${config}_mesh"
        json_add_string ifname "@${meshif}"
        if ! is_layer3_device "$ifname"; then
                [ -n "$index" ] && json_add_string macaddr "$(lua -e "print(require('gluon.util').generate_mac($index))")"
        fi
        json_add_string proto 'gluon_mesh'
        json_add_boolean fixed_mtu 1
        [ -n "$transitive" ] && json_add_boolean transitive "$transitive"
        json_close_object
        ubus call network add_dynamic "$(json_dump)"
}

proto_gluon_wired_teardown() {
        local config="$1"

        proto_init_update "*" 0
        proto_send_update "$config"
}

add_protocol gluon_wired
