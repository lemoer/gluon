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

function proxy_request(host, port, request, prepend_path)
	local sys_sock = require "posix.sys.socket"
	local fd = sys_sock.socket(sys_sock.AF_INET, sys_sock.SOCK_STREAM, 0)

	local res, errmsg, errcode = sys_sock.getaddrinfo (host, port,
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
	local request_path = '/'..table.concat(request, '/')
	local query_string = http:getenv('QUERY_STRING')
	if query_string ~= '' then
		query_string = '?'..query_string .. '&'
	else
		query_string = '?'
	end
	query_string = query_string .. 'prepend_path=' .. prepend_path
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

	function chunk_handler()
		obj = {
			remaining_chunk = "",
			new_data = function()
				local data, err = sys_sock.recv(fd, 1024)
				if data == "" then
					os.exit(0)
				end

				obj.remaining_chunk = obj.remaining_chunk .. data;
			end,
			read_until_token = function(token, skip_token)
				if #obj.remaining_chunk == 0 then
					obj.new_data()
				end
				while true do
					local cut_idx = obj.remaining_chunk:find(token);

					if cut_idx then
						-- we haven't received the token yet
						if skip_token then
							skip = #token;
						else
							skip = 0;
						end
						local result = obj.remaining_chunk:sub(1, cut_idx-1)
						obj.remaining_chunk = obj.remaining_chunk:sub(cut_idx + skip)

						return result
					else
						obj.new_data()
					end
				end
			end,
			read_characters = function(length)
				if #obj.remaining_chunk == 0 then
					obj.new_data()
				end
				while true do
					if #obj.remaining_chunk >= length then
						-- we haven't received enough characters
						local result = obj.remaining_chunk:sub(1, length)
						obj.remaining_chunk = obj.remaining_chunk:sub(length+1)

						return result
					else
						obj.new_data()
					end
				end
			end,
			skip_chars = function(n)
				obj.read_characters(n)
			end
		}

		return obj
	end

	local ch = chunk_handler()
	local line
	local first_line = true
	local received_headers = {}

	--  Read and parse the HTTP Header
	repeat
		line = ch.read_until_token('\r\n', true)
		if first_line then
			_, _, version, status, req = line:find("^HTTP/([%d.]*)%s(%d*)%s(%a*)")
			http:status(tonumber(status), req)
			first_line = false
		else
			local _, _, key, value = line:find("^([^:]*):%s*(.*)$")
			if key then
				received_headers[key] = value
				if key ~= 'Connection' and key ~= 'Keep-Alive' and key ~= 'Transfer-Encoding' then
					http:header(key, value)
				end
			end
		end
	until(line == '')

	-- End of Header / Start of Content

	if received_headers['Transfer-Encoding'] == 'chunked' then
		while true do
			local len = ch.read_until_token('\r\n', true)
			len = tonumber(len, 16)
			local transfer_encoded_chunk = ch.read_characters(len)
			ch.skip_chars(2) -- skip '\r\n'
			http:write(transfer_encoded_chunk)
		end
	else
		local content = ch.read_characters(tonumber(received_headers['Content-Length']))
		http:write(content)
	end

	http.output:flush()
	http.output:close()
	os.exit(0)
end


-- register routes for the remotes
for index, remote in pairs(remotes) do
	local hostname = '[2001:678:978:199:5054:ff:fe12:3457]'

	if (#request > 3) and (request[1] == 'nodes')
		               and (request[2] == remote.nodeid)
		               and (request[3] == 'proxy') then
		table.remove(request, 1)
		table.remove(request, 1)
		table.remove(request, 1)
		local prepend_path = '/cgi-bin/controller/nodes/'..remote.nodeid..'/proxy'
		proxy_request('127.0.0.1', 37000+remote.index, request, prepend_path)
	end

	entry({"nodes", remote.nodeid},
		redirect({"nodes", remote.nodeid, "status"}), _("Information"), 1)
	entry({"nodes", remote.nodeid, "status"},
		iframe('http://['..remote.address..']/'), _("Information"), 1)
	entry({"nodes", remote.nodeid, "config"},
		iframe('/cgi-bin/controller/nodes/'..remote.nodeid..'/proxy/cgi-bin/config/wizard'), _("Information"), 1)
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
