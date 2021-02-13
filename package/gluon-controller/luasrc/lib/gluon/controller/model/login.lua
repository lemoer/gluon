--[[
Copyright 2021 Leonardo Mörlein <me@irrelefant.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0
]]--

local ubus = require 'ubus'

local title = translate("Login")

local f = Form(title)
f.submit = 'Login'
f.reset = false

local s = f:section(Section)

local username = s:option(Value, "username", translate("Username"))
local password = s:option(Value, "password", translate("Password"))
password.password = true

function f:write()
	local conn = ubus.connect()
	local session = conn:call("session", "login", {
		username=username.data,
		password=password.data
	})

	if not session then
		f.description = "ERROR: Login failed!"
		return
	end

	http:header('Set-Cookie', 'ubus_rpc_session='..session.ubus_rpc_session..'; SameSite=lax')
	http:redirect('/cgi-bin/controller/')
end

return f
