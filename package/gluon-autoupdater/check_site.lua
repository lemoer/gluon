need_site_string 'autoupdater.branch'

local function check_branch(k, _, conf_name)
   assert_uci_name(k, conf_name)

   local prefix = string.format('autoupdater.branches[%q].', k)

   need_site_string(prefix .. 'name')
   need_string_array_match(prefix .. 'mirrors', '^http://')
   need_site_number(prefix .. 'good_signatures')
   need_site_string_array_match(prefix .. 'pubkeys', '^%x+$')
end

need_table('autoupdater.branches', check_branch)
