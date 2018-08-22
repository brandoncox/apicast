local context_content = require('context_content')
local cjson = require('cjson')
local policy = require('apicast.policy')
local _M = policy.new('Liquid context debug')

local new = _M.new

function _M.new(config)
  local self = new(config)
  return self
end

function _M.content(_, context)
  local content = context_content.from(context)

  -- There is a lrucache instance with a table that maps service ids (numbers)
  -- to hosts. So we can have something like { [123456] = "127.0.0.1" }. This
  -- is a problem when encoding the table into JSON because it's a table with
  -- many positions but only one != null. When converting this, cjson raises
  -- an "Excessively sparse arrays" error:
  -- https://github.com/efelix/lua-cjson/blob/4f27182acabc435fcc220fdb710ddfaf4e648c86/README#L140
  -- With this call we just convert that number into a string. Not a big deal
  -- since nobody is going to use those fields from the lrucache instance in
  -- liquid.
  cjson.encode_sparse_array(true)

  ngx.say(cjson.encode(content))
end

return _M
