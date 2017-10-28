if need_site_table('config_mode', nil, false) and need_site_table('config_mode.owner', nil, false) then
  need_site_boolean('config_mode.owner.obligatory', false)
end
