local cjson = require('cjson')

local LiquidContextDebug = require 'apicast.policy.liquid_context_debug'

describe('Liquid context debug policy', function()
  describe('.content', function()
    before_each(function()
      stub(ngx, 'say')
    end)

    it('calls ngx.say with the content of the context in JSON', function()
      local context = { a = 1, b = 2, c = 3 }
      local json_context = cjson.encode(context)
      local liquid_context_debug = LiquidContextDebug.new()

      liquid_context_debug:content(context)

      assert.stub(ngx.say).was_called_with(json_context)
    end)
  end)
end)
