if need_site_table('config_mode', nil, false) and need_site_table('config_mode.remote_login', nil, false) then
  need_site_boolean('config_mode.remote_login.show_password_form', false)
  need_site_number('config_mode.remote_login.min_password_length', false)
end
