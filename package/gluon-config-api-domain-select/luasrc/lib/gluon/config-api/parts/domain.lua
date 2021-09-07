
local json = require 'jsonc'
local util = require 'gluon.util'

local function hide_domain_code(domain, code, selected_domain)
	if configured and code == selected_domain then
		return false
	elseif type(domain.hide_domain) == 'table' then
		return util.contains(domain.hide_domain, code)
	else
		return domain.hide_domain
	end
end

local function get_domain_list()
	local uci = require('simple-uci').cursor()
	local selected_domain = uci:get('gluon', 'core', 'domain')

	local list = {}
	for _, domain_path in ipairs(util.glob('/lib/gluon/domains/*.json')) do
		local domain_code = domain_path:match('([^/]+)%.json$')
		local domain = assert(json.load(domain_path))

		if not hide_domain_code(domain, domain_code, selected_domain) then
			table.insert(list, {
				domain_code = domain_code,
				domain_name = domain.domain_names[domain_code],
			})
		end
	end

	table.sort(list, function(a, b) return a.domain_name < b.domain_name end)
	return list
end


local M = {}

function M.schema(site, platform)
	local domain_codes = {}
	local domain_names = {}
	for _, v in ipairs(get_domain_list()) do
		table.insert(domain_codes, v.domain_code)
		table.insert(domain_names, v.domain_name)
	end

	return {
		properties = {
			wizard = {
				properties = {
					domain = {
						type = 'string',
						enum = domain_codes,
						enum_titles = domain_names
					}
				}
			}
		}
	}
end

function M.set(config, uci)
	-- TODO: trigger gluon-reconfigure
	-- TODO: maybe return to default domain here ??? but this is done by
	--       gluon-reconfigure anyways, I guess...
	uci:set('gluon', 'core', 'domain', config.wizard.domain)
	uci:save('gluon')
end

function M.get(uci, config)
	config.wizard.domain = uci:get('gluon', 'core', 'domain')
end

return M
