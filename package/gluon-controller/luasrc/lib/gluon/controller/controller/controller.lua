local json = require 'jsonc'
local site = require 'gluon.site'
local util = require 'gluon.util'
local ubus = require 'ubus'

package 'gluon-controller'

function redirect(path)
	return call(function(http, renderer)
		http:header('Cache-Control', 'no-cache, no-store, must-revalidate')
		http:redirect('/cgi-bin/controller/'..table.concat(path, '/'))
		http:close()
	end)
end

function iframe(iframe_src)
	return template("iframe", { iframe_src = iframe_src })
end

-- load remotes from uci
local remotes = {}
local uci = require('simple-uci').cursor()
uci:foreach('gluon-controller', 'remote', function(remote)
	table.insert(remotes, remote)
end)

function get_session()
	-- returns the session if it exists or return nil.

	local ubus_rpc_session = http:getcookie("ubus_rpc_session")

	if not ubus_rpc_session then
		return nil
	end

	local conn = ubus.connect()
	local session =  conn:call("session", "get", {
		ubus_rpc_session=ubus_rpc_session
	})

	if not session then
		return nil
	end

	return session.values
end

function logout()
	local ubus_rpc_session = http:getcookie("ubus_rpc_session")
	if not ubus_rpc_session then
		return nil
	end

	local conn = ubus.connect()
	return conn:call("session", "destroy", {
		ubus_rpc_session=ubus_rpc_session
	})
end

-- redirect from controller/ to something
-- TODO: what to do if no node is configured!
-- TODO: what to do if no node with index 1 is configured
if #remotes > 0 then
	entry({}, redirect({"nodes", remotes[1].nodeid}))
end

-- TODO: What is 40?
entry({"login"}, model('login', { http=http }), _("Login"), 40)


entry({"logout"}, call(function(http, renderer)
	logout()
	http:redirect('/cgi-bin/controller/test')
	http:close()
end))

session = get_session()
if not session and (#request > 0) and (request[1] ~= 'login') then
	-- To avoid leaking the available routes to unauthorized clients, we redirect
	-- everything to the login page here.
	http:redirect('/cgi-bin/controller/login')
	http:close()
end


entry({"test"}, call(function(http, renderer)
	if session then
		http:write(session.username)
	else
		http:write("no login")
	end
	http:close()
end))


-- register routes for the remotes
for index, remote in pairs(remotes) do
	local hostname = 'localhost'

	entry({"nodes", remote.nodeid},
		redirect({"nodes", remote.nodeid, "status"}), _("Information"), 1)
	entry({"nodes", remote.nodeid, "status"},
		iframe('http://['..remote.address..']/'), _("Information"), 1)
	entry({"nodes", remote.nodeid, "config"},
		iframe('http://'..hostname..':'..tostring(37000+remote.index)..'/'), _("Information"), 1)
	entry({"nodes", remote.nodeid, "map"},
		iframe('https://hannover.freifunk.net/karte/#/en/map/'..remote.nodeid), _("Information"), 1)
	entry({"nodes", remote.nodeid, "stats"},
		iframe('https://stats.ffh.zone/d/000000021/router-fur-meshviewer?orgId=1&var-node='..remote.nodeid..'&from=now-12h&to=now-1m'), _("Information"), 1)
	entry({"nodes", remote.nodeid, "keepitup"},
		iframe('https://keepitup.ffh.zone/node/'..remote.nodeid), _("Information"), 1)

	entry({"nodes", remote.nodeid, "edit"},
		model("create_or_update_node", { remote=remote }), _("Information"), 1)
end

req = request

entry({"nodes"}, template("listnodes"), _("Network"), 40)
entry({"nodes", "new"}, model("create_or_update_node"), _("Network"), 40)