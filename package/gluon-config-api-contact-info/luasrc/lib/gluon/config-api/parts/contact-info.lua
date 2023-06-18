
local M = {}

function M.info(site)
	return {}
end

function M.validate(config, uci)
	local validation = require 'gluon.validation'

	validation.need_string(config, { 'contact' }, false)
end

function M.set(config, uci)
	local owner = uci:get_first("gluon-node-info", "owner")

	uci:set("gluon-node-info", owner, "contact", config.contact)
	uci:save("gluon-node-info")
end

function M.get(uci, null)
	local owner = uci:get_first("gluon-node-info", "owner")

	return {
		contact = uci:get("gluon-node-info", owner, "contact") or null
	}
end

return M