local json = require 'jsonc'
local site = require 'gluon.site'
local util = require 'gluon.util'

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

-- redirect from controller/ to something
-- TODO: what to do if no node is configured!
-- TODO: what to do if no node with index 1 is configured
entry({}, redirect({"nodes", remotes[1].nodeid}))

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
end

entry({"nodes"}, template("listnodes"), _("Network"), 40)
entry({"nodes", "new"}, model("newnode"), _("Network"), 40)
