
local M = setmetatable({}, { __index = _G })

function M.extend(path, c)
	if not path then return nil end

	local p = {unpack(path)}

	for _, e in ipairs(c) do
		p[#p+1] = e
	end
	return p
end

local function format(val)
	if type(val) == 'string' then
		return string.format('%q', val)
	else
		return tostring(val)
	end
end

local function loadpath(path, base, c, ...)
	if not c or base == nil then
		return base
	end

	if type(base) ~= 'table' then
		if path then
			var_error(path, base, 'be a table')
		else
			return nil
		end
	end

	return loadpath(M.extend(path, {c}), base[c], ...)
end

local function loadvar(obj, path)
    return loadpath({}, obj, unpack(path))
end

local function path_to_string(path)
    return table.concat(path, '.')
end

local function array_to_string(array)
	local strings = {}
	for i, v in ipairs(array) do
		strings[i] = format(v)
	end
	return '[' .. table.concat(strings, ', ') .. ']'
end

local function var_error(path, val, msg)
	local found = 'unset'
	if val ~= nil then
		found = string.format('%s (a %s value)', format(val), type(val))
	end

	validation_error = {
		type = "validation_error",
		msg = string.format('Expected %s to %s, but it is %s.', path_to_string(path), msg, found)
	}

	error(validation_error)
end

function need(obj, path, check, required, msg)
    local val = loadvar(obj, path)
    if required == false and val == nil then
        return nil
    end

	if not check(val) then
		var_error(path, val, msg)
	end

    return val
end

local function check_type(t)
	return function(val)
		return type(val) == t
	end
end

local function check_stringtype(subcheck)
	return function(val)
		return type(val) == 'string' and subcheck(val)
	end
end

local function need_type(obj, path, type, required, msg)
	return M.need(obj, path, check_type(type), required, msg)
end

function M.need_string(obj, path, required)
	return need_type(obj, path, 'string', required, 'be a string')
end

local function check_one_of(array)
	return function(val)
		for _, v in ipairs(array) do
			if v == val then
				return true
			end
		end
		return false
	end
end

function M.need_one_of(obj, path, array, required)
	return M.need(obj, path, check_one_of(array), required, 'be one of the given array ' .. array_to_string(array))
end

-- IPv4 & IPv6 address validation

local function ip4addr(val)
	local g = '(%d%d?%d?)'
	local v1, v2, v3, v4 = val:match('^'..((g..'%.'):rep(3))..g..'$')
	local n1, n2, n3, n4 = tonumber(v1), tonumber(v2), tonumber(v3), tonumber(v4)

	if not (n1 and n2 and n3 and n4) then return false end

	return (
		(n1 >= 0) and (n1 <= 255) and
		(n2 >= 0) and (n2 <= 255) and
		(n3 >= 0) and (n3 <= 255) and
		(n4 >= 0) and (n4 <= 255)
	)
end

local function ip6addr(val)
	local g1 = '%x%x?%x?%x?'

	if not val:match('::') then
		return val:match('^'..((g1..':'):rep(7))..g1..'$') ~= nil
	end

	if
		val:match(':::') or val:match('::.+::') or
		val:match('^:[^:]') or val:match('[^:]:$')
	then
		return false
	end

	local g0 = '%x?%x?%x?%x?'
	for i = 2, 7 do
		if val:match('^'..((g0..':'):rep(i))..g0..'$') then
			return true
		end
	end

	if val:match('^'..((g1..':'):rep(7))..':$') then
		return true
	end
	if val:match('^:'..((':'..g1):rep(7))..'$') then
		return true
	end

	return false
end


local function ipaddr(val)
	return ip4addr(val) or ip6addr(val)
end

function M.need_ipaddr(obj, path, required)
	return M.need(obj, path, check_stringtype(ipaddr), required, 'be a valid IP address')
end

function M.need_ip4addr(obj, path, required)
	return M.need(obj, path, check_stringtype(ip4addr), required, 'be a valid IPv4 address')
end

function M.need_ip6addr(obj, path, required)
	return M.need(obj, path, check_stringtype(ip6addr), required, 'be a valid IPv6 address')
end

function M.need_array(obj, path, subcheck, required)
	local val = need_type(obj, path, 'table', required, 'be an array')
	if not val then
		return nil
	end

	if subcheck then
		for i = 1, #val do
			subcheck(obj, M.extend(path, {i}))
		end
	end

	return val
end

return M