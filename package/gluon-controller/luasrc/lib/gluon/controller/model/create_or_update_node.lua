--[[
Copyright 2014 Nils Schneider <nils@nilsschneider.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0
]]--

local uci = require("simple-uci").cursor()
local math = require 'math'

local wan = uci:get_all("network", "wan")
local wan6 = uci:get_all("network", "wan6")
local dns_static = uci:get_first("gluon-wan-dnsmasq", "static")

local title = translate("Create a new node")
if remote then
	title = translate("Update node")
end

local f = Form(title)

local max_index = 0
uci:foreach('gluon-controller', 'remote', function(remote)
	max_index = math.max(max_index, tonumber(remote.index))
end)

local s = f:section(Section)

local uci_section = nil
local nodeid = s:option(Value, "nodeid", translate("Node-ID"))
nodeid.datatype = 'minlength(12)'
local name = s:option(Value, "name", translate("Name"))
local address = s:option(Value, "address", translate("IPv6-Address"))
address.datatype = 'ip6addr'

if remote then
	uci_section = remote['.name']
	nodeid.default = remote.nodeid
	name.default = remote.name
	address.default = remote.address
end

function f:write()
	uci_section = uci_section or uci:add("gluon-controller", "remote")
	uci:section("gluon-controller", "remote", uci_section, {
		index = max_index + 1,
		name = name.data,
		nodeid = nodeid.data,
		address = address.data,
	})
	uci:commit("gluon-controller")

	assert(os.execute('/etc/init.d/gluon-controller restart') == 0)
end

return f
