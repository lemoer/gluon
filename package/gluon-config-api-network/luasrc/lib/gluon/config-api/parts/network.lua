
local M = {}

-- {
--     "info": {
--     },
--     "config": {
--         "wan": {
--             "ipv4": {
--                 "proto": "static",
--                 "ip": "192.168.0.123",
--                 "netmask": "255.255.255.0",
--                 "gateway": "192.168.0.1"
--             },
--             "ipv6": {
--                 "proto": "automatic"
--             },
--             "static_dns_servers": ["8.8.8.8", "1.1.1.1"]
--         },
--     }
-- }


function M.info(site, uci)
	local features = {}
	local dns_static = uci:get_first("gluon-wan-dnsmasq", "static")
	features.static_dns_servers = dns_static ~= nil

	return {
		features = features
	}
end

function M.validate(config, uci)
	local validation = require 'gluon.validation'

	-- ipv4

	local ipv4_proto = validation.need_one_of(config, {'wan', 'ipv4', 'proto'}, {'static', 'dhcp', 'none'})
	if ipv4_proto == 'static' then
		validation.need_ip4addr(config, {'wan', 'ipv4', 'ip'})
		validation.need_ip4addr(config, {'wan', 'ipv4', 'netmask'})
		validation.need_ip4addr(config, {'wan', 'ipv4', 'gateway'})
	end

	-- ipv6

	local ipv6_proto = validation.need_one_of(config, {'wan', 'ipv6', 'proto'},  {'static', 'dhcpv6', 'none'})
	if ipv6_proto == 'static' then
		validation.need_ip6addr(config, {'wan', 'ipv6', 'ip'})
		validation.need_ip6addr(config, {'wan', 'ipv6', 'gateway'})
	end

	-- static dns servers
	local dns_static = uci:get_first("gluon-wan-dnsmasq", "static")
	if dns_static then
		validation.need_array(config, {'wan', 'static_dns_servers'}, validation.need_ipaddr)
	end
end

function M.set(config, uci)
	-- ipv4
	uci:set("network", "wan", "proto", config.wan.ipv4.proto)
	if config.wan.ipv4.proto == "static" then
		uci:set("network", "wan", "ipaddr", config.wan.ipv4.ip)
		uci:set("network", "wan", "netmask", config.wan.ipv4.netmask)
		uci:set("network", "wan", "gateway", config.wan.ipv4.gateway)
	else
		uci:delete("network", "wan", "ipaddr")
		uci:delete("network", "wan", "netmask")
		uci:delete("network", "wan", "gateway")
	end

	-- ipv6
	uci:set("network", "wan6", "proto", config.wan.ipv6.proto)
	if config.wan.ipv6.proto == "static" then
		uci:set("network", "wan6", "ip6addr", config.wan.ipv6.ip)
		uci:set("network", "wan6", "ip6gw", config.wan.ipv6.gateway)
	else
		uci:delete("network", "wan6", "ip6addr")
		uci:delete("network", "wan6", "ip6gw")
	end

	-- static dns servers
	local dns_static = uci:get_first("gluon-wan-dnsmasq", "static")

	if dns_static then
		uci:set_list("gluon-wan-dnsmasq", dns_static, "server", config.wan.static_dns_servers)
	end

	uci:save("network")
end

function M.get(uci, null)
	-- ipv4
	local wan = uci:get_all("network", "wan")
	local ipv4 = {
		proto = wan.proto
	}

	if wan.proto == "static" then
		ipv4.ip = wan.ipaddr
		ipv4.netmask = wan.netmask or "255.255.225.0"
		ipv4.gateway = wan.gateway
	end

	-- ipv6
	local wan6 = uci:get_all("network", "wan6")
	local ipv6 = {
		proto = wan6.proto
	}

	if wan6.proto == "static" then
		ipv6.ip = wan6.ip6addr
		ipv6.gateway = wan6.ip6gw
	end

	-- static dns servers
	local dns_static = uci:get_first("gluon-wan-dnsmasq", "static")
	local static_dns_servers = nil

	if dns_static then
		static_dns_servers = uci:get_list("gluon-wan-dnsmasq", dns_static, "server")
	end

	return {
		wan = {
			ipv4 = ipv4,
			ipv6 = ipv6,
			static_dns_servers = static_dns_servers
		},
	}
end

return M