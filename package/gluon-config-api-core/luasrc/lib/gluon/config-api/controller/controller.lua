local os = require 'os'
local json = require 'jsonc'
local site = require 'gluon.site'
local glob = require 'posix.glob'
local libgen = require 'posix.libgen'
local simpleuci = require 'simple-uci'

package 'gluon-config-api'

function load_parts()
	local parts = {}
	return parts
end

function config_get(parts)
	local config = {}
	local uci = simpleuci.cursor()

	for _, part in pairs(parts) do
		part.get(uci, config)
	end

	return config
end

function schema_get(parts)
	local total_schema = {}
	for _, part in pairs(parts) do
		total_schema = schema.merge_schemas(total_schema, part.schema(site, nil))
	end
	return total_schema
end

function config_set(parts, config)
	local uci = simpleuci.cursor()

	for _, part in pairs(parts) do
		part.set(config, uci)
	end

	-- commit all uci configs
	os.execute('uci commit')
end

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

local function json_response(http, obj)
	local result = json.stringify(obj, true)
	http:header('Content-Type', 'application/json; charset=utf-8')
	-- Content-Length is needed, as the transfer encoding is not chunked for
	-- http method OPTIONS.
	http:header('Content-Length', tostring(#result))
	http:write(result..'\n')
end

local function get_request_body_as_json(http)
	local request_body = ""
	pump(http.input, function (data)
		if data then
			request_body = request_body .. data
		end
	end)

	local data = json.parse(request_body)

	if not data then
		http:status(400, 'Bad Request')
		json_response(http, { status = 400, error = "Bad JSON in Body" })
		http:close()
		return
	end

	return data
end

-- this is a hack for jsonc to make sure, it interprets an empty object as object and not as array
function jsonc_ensure_object(input)
	if type(input) ~= "table" then
		return input
	end
	input[{}] = ""; -- this will not end up in the json
	return input
end


-- for _, f in pairs(glob.glob('/lib/gluon/config-api/parts/*.lua')) do
-- 	table.insert(parts, dofile(f))
-- end

function rest_api_handler(module_path)
	return call(function(http, renderer)
		local uci = simpleuci.cursor()
		local M = dofile(module_path)
	
		if http.request.env.REQUEST_METHOD == 'GET' then
			jsonc_null = function() end -- this is a hack for jsonc to insert null into the json
			json_response(http, {
				info = jsonc_ensure_object(M.info(site)),
				config = jsonc_ensure_object(M.get(uci, jsonc_null))
			})
		elseif http.request.env.REQUEST_METHOD == 'PUT' then
			local body = get_request_body_as_json(http)
			local info = M.info(site)

			if M.set(body.config, uci) then
				-- commit all uci configs
				os.execute('uci commit')
				json_response(http, { status = 200, error = "Accepted" })
			else
				http:status(400, 'Bad Request')
				json_response(http, { status = 400, error = "Validation Error" })
			end
		else
			http:status(501, 'Not Implemented')
			http:header('Content-Length', '0')
			http:write('Not Implemented\n')
		end
	
		http:close()
	end)
end

entry({"v1", "config", "contact-info"}, rest_api_handler('/lib/gluon/config-api/parts/contact-info.lua'))
entry({"v1", "config", "geo-location"}, rest_api_handler('/lib/gluon/config-api/parts/geo-location.lua'))

