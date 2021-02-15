local json = require 'jsonc'
local site = require 'gluon.site'
local util = require 'gluon.util'
local ubus = require 'ubus'
local os = require 'os'

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
if not session and ((#request < 1) or (request[1] ~= 'login')) then
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


local function pump(src, snk)
	while true do
		local chunk, src_err = src()
		local ret, snk_err = snk(chunk, src_err)

		if not (chunk and ret) then
			local err = src_err or snk_err
			if err then
				return nil, err
			else
				return true
			end
		end
	end
end

if (#request > 0) and (request[1] == 'proxy') then
	local sys_sock = require "posix.sys.socket"
	local fd = sys_sock.socket(sys_sock.AF_INET, sys_sock.SOCK_STREAM, 0)

	local res, errmsg, errcode = sys_sock.getaddrinfo ("127.0.0.1", "http",
		{ family = sys_sock.IF_INET, socktype = sys_sock.SOCK_STREAM })
	local addr = res[1];

	sys_sock.connect(fd, addr)

	function send_header(fd, header_name, value)
		sys_sock.send(fd, header_name..': '..value..'\r\n')
	end
	function forward_header(fd, header_name, env_name)
		if http:getenv(env_name) then
			send_header(fd, header_name, http:getenv(env_name))
		end
	end

	local request_method = http:getenv('REQUEST_METHOD')
	local request_path = '/cgi-bin/status'
	local query_string = http:getenv('QUERY_STRING')
	if query_string ~= '' then
		query_string = '?'..query_string
	end
	local host = 'localhost'

	-- We try to forward all http headers, that uhttpd provides in its environment
	-- variables. This reasonable, as we can't do more here from cgi, but also
	-- because we expect the proxy targets to be uhttp aswell.
	sys_sock.send(fd, request_method..' '..request_path..query_string.." HTTP/1.1\r\n")
	send_header(fd, 'Host', host)
	forward_header(fd, 'X-Forwarded-Host', 'HTTP_HOST')
	send_header(fd, 'X-Forwarded-Proto', 'http')  -- TODO: this can either be http or https
	forward_header(fd, 'User-Agent', 'HTTP_USER_AGENT')
	forward_header(fd, 'Content-Type', 'CONTENT_TYPE')
	forward_header(fd, 'Accept', 'HTTP_ACCEPT')
	forward_header(fd, 'Accept-Charset', 'HTTP_ACCEPT_CHARSET')
	forward_header(fd, 'Accept-Encoding', 'HTTP_ACCEPT_ENCODING')
	forward_header(fd, 'Accept-Language', 'HTTP_ACCEPT_LANGUAGE')
	forward_header(fd, 'Origin', 'HTTP_ORIGIN')
	forward_header(fd, 'Referer', 'HTTP_REFERER')
	send_header(fd, 'Connection', 'close')

	-- TODO: HTTP_CONNECTION
	-- TODO: HTTP_X_HTTP_METHOD_OVERRIDE ?
	-- TODO: HTTP_AUTH_USER ?
	-- TODO: HTTP_AUTH_PASS ?
	-- TODO: HTTP_COOKIE ?
	-- TODO: HTTP_AUTHORIZATION ?

	-- end of header
	sys_sock.send(fd, '\r\n')

	-- data
	pump(http.input, function (chunk)
		if not chunk then
			return
		end
		sys_sock.send(fd, chunk)
		return true
	end)

	--sys_sock.shutdown (fd, sys_sock.SHUT_WR)

	local header = ""
	local header_finished = false
	local chunk_len = 0
	local buf = ""
	--http:write("hey")
	--http:status()
	n = 1;
	pump(function ()
		local data, err = sys_sock.recv(fd, 1024)
		if data == "" then
			return nil
		end
		return data
	end, function(chunk)
		--http:write('hi')
		if not chunk then
			return
		end
		if not header_finished then
			-- strip first line (HTTP ...)
			local idx = chunk:find('\r\n\r\n')
			if not idx then
				header = header + chunk
				return
			end

			header = chunk:sub(0, idx+4)
			chunk = chunk:sub(idx+4)
			local idx2 = chunk:find('\r\n')
			chunk_len = tonumber(chunk:sub(0, idx2), 16)
			chunk = chunk:sub(idx2+2)
			header_finished = true
			http.output:write('Status: ok\r\n\r\n')
			--http.output:write('aaa')

		end

		if buf ~= "" then
			chunk = buf..chunk
			buf = ""
		end

		--http.output:write("\nHI("..tostring(#chunk)..'|'..tostring(chunk_len)..'|'..tostring(idx2)..")")
		while chunk ~= "" do
			--http.output:write("\nAA("..tostring(#chunk)..'|'..tostring(chunk_len)..'|'..tostring(idx2)..")")
			if #chunk < chunk_len then
				chunk_len = chunk_len - #chunk
				http.output:write(chunk)
				chunk = ""
				--http.output:write("HEY")
				--http.output:write("\nHA("..tostring(#chunk)..'|'..tostring(chunk_len)..'|'..tostring(idx2)..")")
				return true
			else
				local wr = chunk:sub(0, chunk_len)
				http.output:write(wr)
				if chunk_len then
					chunk = chunk:sub(chunk_len+2)
				end
				-- TODO: chunk might be too short now
				local idx2 = chunk:find('\r\n')
				if not idx2 then
					--http.output:write("N")
					chunk_len = 0
					buf = chunk
					return true
				end
				chunk_len = tonumber(chunk:sub(0, idx2), 16)
				--http.output:write("chunk_len: [] "..tostring(chunk_len).."(-)"..tostring(#chunk))
				chunk = chunk:sub(idx2+2)
				--http.output:write("\nHO("..tostring(#chunk)..'|'..tostring(chunk_len)..'|'..tostring(idx2)..")")
			end
		end
		return true
	end)

	http.output:flush()
	http.output:close()
	os.exit(0)
end


-- register routes for the remotes
for index, remote in pairs(remotes) do
	local hostname = '[2001:678:978:199:5054:ff:fe12:3457]'

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
