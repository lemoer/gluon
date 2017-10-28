local function loadvar(varname)
   local ok, val = pcall(assert(loadstring('return domain.' .. varname)))
   if ok and val ~= nil then
      return val, 'domains/'..domain_name..'.conf'
   end

   ok, val = pcall(assert(loadstring('return site.' .. varname)))
   if ok and val ~= nil then
      return val, 'site.conf'
   else
      return nil, 'site.conf or domains/'..domain_name..'.conf'
   end
end

local function loadvar_domain(varname)
   local ok, val = pcall(assert(loadstring('return domain.' .. varname)))
   if ok then
      return val, 'domains/'..domain_name..'.conf'
   else
      return nil, 'domains/'..domain_name..'.conf'
   end
end

local function loadvar_site(varname)
   ok, val = pcall(assert(loadstring('return site.' .. varname)))
   if ok then
      return val, 'site.conf'
   else
      return nil, 'site.conf'
   end
end

local function array_to_string(array)
   local string = ''
   for _, v in ipairs(array) do
      if #string >= 1 then
         string = string .. ', '
      end
      string = string .. v
   end
   return '[' .. string .. ']'
end

local function assert_one_of(var, array, msg)
   for _, v in ipairs(array) do
      if v == var then
         return true
      end
   end

   error(msg)
end

local function assert_type(var, t, msg)
   assert(type(var) == t, msg)
end

-- returns an unique keys in keys of returned table
function keys_merged(a, b)
   keys_table = {}
   for k, _ in pairs(a or {}) do
      keys_table[k] = 1
   end
   for k, _ in pairs(b or {}) do
      keys_table[k] = 1
   end
   return keys_table
end

function forbid_in_domain(varname)
   local ok, val = pcall(assert(loadstring('return domain.' .. varname)))
   assert(not ok or val == nil, "domains/"..domain_name..".conf error: `"..varname.."` is not allowed in domain specific config.")
end

function forbid_in_site(varname)
   local ok, val = pcall(assert(loadstring('return site.' .. varname)))
   assert(not ok or val == nil, "site.conf error: `"..varname.."` is not allowed in site config.")
end

function assert_uci_name(var, conf_name)
   -- We don't use character classes like %w here to be independent of the locale
   assert(var:match('^[0-9a-zA-Z_]+$'), conf_name.." error: `" .. var .. "' is not a valid config section name (only alphanumeric characters and the underscore are allowed)")
end


function _need_string(loadvar, varname, required)
   local var, conf_name = loadvar(varname)

   if required == false and var == nil then
      return nil, conf_name
   end

   assert_type(var, 'string', conf_name .. " error: expected `" .. varname .. "' to be a string")
   return var, conf_name
end

function _need_string_match(loadvar, varname, pat, required)
   local var, conf_name = _need_string(loadvar, varname, required)

   if not var then
      return nil
   end

   assert(var:match(pat), conf_name.." error: expected `" .. varname .. "' to match pattern `" .. pat .. "'")

   return var
end

function _need_number(loadvar, varname, required)
   local var, conf_name = loadvar(varname)

   if required == false and var == nil then
      return nil
   end

   assert_type(var, 'number', conf_name.." error: expected `" .. varname .. "' to be a number")

   return var
end

function _need_boolean(loadvar, varname, required)
   local var, conf_name = loadvar(varname)

   if required == false and var == nil then
      return nil
   end

   assert_type(var, 'boolean', conf_name.." error: expected `" .. varname .. "' to be a boolean")

   return var
end

local function __need_array_from_var(var, varname, subcheck, required, conf_name)
   if required == false and var == nil then
      return nil
   end

   assert_type(var, 'table', conf_name.." error: expected `" .. varname .. "' to be an array")

   for _, e in ipairs(var) do
      subcheck(e)
   end

   return var
end

function _need_array(loadvar, varname, subcheck, required)
   local var, conf_name = loadvar(varname)
   return __need_array_from_var(var, varname, subcheck, required, conf_name)
end


function _need_table(loadvar, varname, subcheck, required)
   local var, conf_name = loadvar(varname)

   if required == false and var == nil then
      return nil
   end

   assert_type(var, 'table', conf_name.." error: expected `" .. varname .. "' to be a table")

   local dvar = loadvar_domain(varname)
   local svar = loadvar_site(varname)

   if subcheck then
      for k, _ in pairs(keys_merged(dvar, svar)) do
         subcheck(k, conf_name)
      end
   end

   return var
end

function _need_one_of(loadvar, varname, array, required)
   local var, conf_name = loadvar(varname)

   if required == false and var == nil then
      return nil
   end

   assert_one_of(var, array, conf_name.." error: expected `" .. varname .. "' to be one of given array: " .. array_to_string(array))

   return var
end

function _need_string_array(loadvar, varname, required)
   local var, conf_name = loadvar(varname)
   local ok, var = pcall(__need_array_from_var, var, varname, function(e) assert_type(e, 'string') end, required, conf_name)
   assert(ok, conf_name.." error: expected `" .. varname .. "' to be a string array")
   return var
end

function _need_string_array_match(loadvar, varname, pat, required)
   local var, conf_name = loadvar(varname)
   local ok, var = pcall(__need_array_from_var, var, varname, function(e) assert(e:match(pat)) end, required, conf_name)
   assert(ok, conf_name.." error: expected `" .. varname .. "' to be a string array matching pattern `" .. pat .. "'")
   return var
end

function _need_array_of(loadvar, varname, array, required)
   local var, conf_name = loadvar(varname)
   local ok, var = pcall(__need_array_from_var, var, varname, function(e) assert_one_of(e, array) end, required, conf_name)
   assert(ok, conf_name.." error: expected `" .. varname .. "' to be a subset of given array: " .. array_to_string(array))
   return var
end

-- wrap need_* in need_site_* and need_domain_*

local function wrap_need(fun, with, loadvar_fun)
   return function(varname, ...)
      if with ~= nil then
         with(varname)
      end
      return fun(loadvar_fun, varname, unpack({...}))
   end
end

local need_names = {
   'string',
   'string_match',
   'number',
   'boolean',
   'array',
   'table',
   'one_of',
   'string_array',
   'string_array_match',
   'array_of'
}
for _, k in pairs(need_names) do
   local fun = _G['_need_'..k]
   _G['need_'..k] = wrap_need(fun, nil, loadvar)
   _G['need_site_'..k] = wrap_need(fun, forbid_in_domain, loadvar_site)
   _G['need_domain_'..k] = wrap_need(fun, forbid_in_site, loadvar_domain)
end
