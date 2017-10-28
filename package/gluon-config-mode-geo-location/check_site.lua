if need_site_table('config_mode', nil, false) and need_site_table('config_mode.geo_location', nil, false) then
  need_site_boolean('config_mode.geo_location.show_altitude', false)
end
