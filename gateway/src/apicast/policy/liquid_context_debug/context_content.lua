local type = type
local pairs = pairs

local _M = {}

-- The context usually contains a lot of information. For example, it includes
-- the whole service configuration. Also, some of the values are objects that
-- we can't really use when evaluating liquid, like functions.
-- That's why we define only a few types of keys and values to return.
local accepted_types_for_keys = {
  string = true,
  number = true,
}

local accepted_types_for_values = {
  string = true,
  number = true,
  table = true
}

local value_from

local ident = function(...) return ... end
local value_from_fun = {
  string = ident, number = ident,
  table = function(table)
    local res = {}
    for k, v in pairs(table) do
      local wanted_types = accepted_types_for_keys[type(k)] and
                           accepted_types_for_values[type(v)]

      if wanted_types then
        res[k] = value_from(v)
      end
    end

    return res
  end
}

value_from = function(object)
  local fun = value_from_fun[type(object)]
  if fun then return fun(object) end
end

local function add_content(object, acc)
  if type(object) ~= 'table' then return nil end

  -- The context is a list where each element has a "current" and a "next".
  local current = object.current
  local next = object.next

  local values_of_current = value_from(current or object)

  for k, v in pairs(values_of_current) do
    if acc[k] == nil then -- to return only the first occurrence
      acc[k] = v
    end
  end

  if next then
    add_content(next, acc)
  end
end

function _M.from(context)
  local res = {}
  add_content(context, res)
  return res
end

return _M
