local announce = require 'gluon.announce'
local deflate = require 'deflate'
local json = require 'luci.jsonc'

local collect = announce.init('/lib/gluon/announce')

module('gluon.announced', package.seeall)

function handle_request(query)
  collectgarbage()

  local m = query:match('^GET ([a-z ]+)$')
  local ret
  if m then
    local data = {}

    for q in m:gmatch('([a-z]+)') do
      local ok, val = pcall(collect, q)
      if ok and val then
        data[q] = val
      end
    end

    if next(data) then
      ret = deflate.compress(json.stringify(data))
    end
  elseif query:match('^[a-z]+$') then
    local ok, val = pcall(collect, query)
    if ok and val then
      ret = json.stringify(val)
    end
  end

  collectgarbage()

  return ret
end
