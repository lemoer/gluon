
local M = {}

function M.info(site)
	return {
		show_altitude = site.config_mode.geo_location.show_altitude(false)
	}
end

function M.set(config, uci)
	local location = uci:get_first("gluon-node-info", "location")

	uci:set("gluon-node-info", location, "share_location",
		config.share_location or false)
	uci:set("gluon-node-info", location, "latitude", config.lat)
	uci:set("gluon-node-info", location, "longitude", config.lon)
	uci:set("gluon-node-info", location, "altitude", config.altitude)

	uci:save("gluon-node-info")
end

function M.get(uci, null)
	local location = uci:get_first("gluon-node-info", "location")
	local lon = uci:get("gluon-node-info", location, "longitude")

	-- if uci:get() returns nil, then altitude will not be present in the result
	local altitude = uci:get("gluon-node-info", location, "altitude")

	if lon then
		return {
			share_location = uci:get_bool("gluon-node-info", location, "share_location"),
			lat = tonumber(uci:get("gluon-node-info", location, "latitude")),
			lon = tonumber(lon),
			
			altitude = tonumber(altitude)
		}
	else
		return null
	end
end

return M
