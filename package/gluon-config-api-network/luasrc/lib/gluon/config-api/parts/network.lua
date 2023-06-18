
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


function M.info(site)
	return {}
end

function M.set(config, uci)
	return true
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

	-- dns
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