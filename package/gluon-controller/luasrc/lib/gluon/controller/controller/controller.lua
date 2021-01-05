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
	remotes[tonumber(remote.index)] = remote
end)

-- redirect from controller/ to something
-- TODO: what to do if no node is configured!
-- TODO: what to do if no node with index 1 is configured
entry({}, redirect({"node", "1"}))

-- register routes for the remotes
for i, remote in pairs(remotes) do
	local hostname = 'localhost'

	entry({"node", tostring(remote.index)},
		redirect({"node", tostring(remote.index), "status"}), _("Information"), 1)
	entry({"node", tostring(remote.index), "status"},
		iframe('http://['..remote.address..']/'), _("Information"), 1)
	entry({"node", tostring(remote.index), "config"},
		iframe('http://'..hostname..':'..tostring(37000+remote.index)..'/'), _("Information"), 1)
end
