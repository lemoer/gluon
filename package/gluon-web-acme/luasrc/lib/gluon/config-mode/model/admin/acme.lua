--[[
Copyright 2021 Leonardo Mörlein <me@irrelefant.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0
]]--

local uci = require("simple-uci").cursor()
local sysconfig = require 'gluon.sysconfig'
local util = require 'gluon.util'

local wan = uci:get_all("network", "wan")
local wan6 = uci:get_all("network", "wan6")
local dns_static = uci:get_first("gluon-wan-dnsmasq", "static")

local f = Form(translate("SSL Certificate"))

if not util.in_setup_mode() then
	f.submit = translate('Save & apply')
end

local acme = uci:get_first('acme', 'acme')

s = f:section(Section, nil, translate(
	'Here you can configure your node to obtain SSL certificates using the Let\'sEncrypt certificate '
	.. 'authority. Please make sure that you configure the dns record appropriately after the node '
	.. 'has rebooted to normal mode. You will find the ip address on the status page of the node. '
	.. 'The node will obtain a staging certificate first and then a production certificate once '
	.. 'the staging certificate is obtained successfully. This way we can ensure a reasonable '
	.. 'retry interval of 2 minutes. By enabling this, you agree to to the terms of service of '
	.. 'Let\'s Encrypt.'
))

local acme_enabled = s:option(Flag, "acme_enable", translate("Obtain SSL Certificate"))
acme_enabled.default = uci:get_bool("acme", "gluon_cert", "enabled")

local acme_email = s:option(Value, "acme_email", translate("Email"))
acme_email.datatype = 'email'
acme_email:depends(acme_enabled, true)
acme_email.default = uci:get("acme", acme, "account_email")

local acme_domains = s:option(DynamicList, "acme_domains", translate("Domains"))
acme_domains.datatype = 'domain'
acme_domains:depends(acme_enabled, true)
acme_domains.default = uci:get_list("acme", "gluon_cert", "domains")


function f:write()
	uci:set("acme", "gluon_cert", "enabled", acme_enabled.data)
	if acme_enabled.data then
		uci:set_list("acme", "gluon_cert", "domains", acme_domains.data)
		uci:set("acme", acme, "account_email", acme_email.data)
	end

	uci:commit("acme")

	if not util.in_setup_mode() then
		util.reconfigure_asynchronously()
	end
end

return f
