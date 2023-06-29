
local M = {}

-- {
--     "info": {
--         "features": [],
--         "switch-type": "none",
--         "physical-interfaces": [
--             "eth0",
--             "eth1"
--         ]
--     },
--     "config": {
--         "iface_lan": {
--             "name": "\/lan",
--             "roles": [
--               "client"
--             ]
--          },
--          "iface_wan": {
--              "name": "\/wan",
--              "roles": [
--                  "uplink"
--              ]
--          }
--     }
-- }


function M.info(site, uci)
    local ethernet = require 'gluon.ethernet'
    local features = {}

    return {
        features = features,
        ["physical-interfaces"] = ethernet.interfaces(),
        ["switch-type"] = ethernet.get_switch_type()
    }
end

function M.validate(config, uci)
    local validation = require 'gluon.validation'

    local function check_iface(config, k)
        validation.need_alphanumeric_key(k)

        validation.need_string(config, validation.extend(k, {'name'}), true)
        -- TODO: check if iface with that name exists
        validation.need_array_of(config, validation.extend(k, {'roles'}), {'client', 'mesh', 'uplink'}, true)

        validation.need_array_elements_exclusive(config, validation.extend(k, {'roles'}), 'client', 'mesh', true)
        validation.need_array_elements_exclusive(config, validation.extend(k, {'roles'}), 'client', 'uplink', true)
    end

    validation.need_table(config, {}, check_iface)
end

function M.set(config, uci)
    uci:foreach('gluon', 'interface', function(config)
        uci:delete('gluon', config['.name'])
    end)

    for k, v in pairs(config) do
        uci:section('gluon', 'interface', k, {
            name = v.name,
            role = v.roles
        })
    end

    uci:save('gluon')
end

function M.get(uci, null)
    local interfaces = {}

    uci:foreach('gluon', 'interface', function(config)
        interfaces[config['.name']] = {
            name = config['name'],
            roles = config['role']
        }
    end)

    return interfaces
end

return M
