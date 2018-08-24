local _M = require('apicast.oauth.oidc')

local jwt_validators = require('resty.jwt-validators')
local jwt = require('resty.jwt')

local rsa = require('fixtures.rsa')

describe('OIDC', function()

  describe(':transform_credentials', function()
    local service = {
      id = 1,
      oidc = {
        issuer = 'https://example.com/auth/realms/apicast',
        config = { id_token_signing_alg_values_supported = { 'RS256' } },
        keys = { somekid = { pem = rsa.pub } },
      }
    }

    before_each(function() jwt_validators.set_system_clock(function() return 0 end) end)

    it('successfully verifies token', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
        payload = {
          iss = service.oidc.issuer,
          aud = 'notused',
          azp = 'ce3b2e5e',
          nbf = 0,
          exp = ngx.now() + 10,
        },
      })

      local credentials, ttl, _, err = oidc:transform_credentials({ access_token = access_token })

      assert(credentials, err)

      assert.same({ app_id  = "ce3b2e5e" }, credentials)
      assert.equal(10, ttl)
    end)

    it('caches verification', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
        payload = {
          iss = service.oidc.issuer,
          aud = {'ce3b2e5e','notused'},
          nbf = 0,
          exp = ngx.now() + 10,
        },
      })

      local stubbed
      for _=1, 10 do
        local credentials, _, _, err = oidc:transform_credentials({ access_token = access_token })
        if not stubbed then
          stubbed = stub(jwt, 'verify_jwt_obj', function(_, jwt_obj, _) return jwt_obj end)
        end
        assert(credentials, err)

        assert.same({ app_id  = "ce3b2e5e" }, credentials)
      end
    end)

    it('verifies iss', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
        payload = {
          iss = service.oidc.issuer,
          aud = 'foobar',
          nbf = 0,
          exp = ngx.now() + 10,
        },
      })

      local credentials, _, _, err = oidc:transform_credentials({ access_token = access_token })

      assert(credentials, err)
    end)


    it('verifies nbf', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
        payload = {
          iss = service.oidc.issuer,
          aud = 'foobar',
          nbf = 1,
          exp = ngx.now() + 10,
        },
      })

      local credentials, _, _, err = oidc:transform_credentials({ access_token = access_token })

      assert.falsy(credentials)
      assert.truthy(err)
    end)

    it('verifies exp', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
        payload = {
          iss = service.oidc.issuer,
          aud = 'foobar',
          nbf = 0,
          exp = 1,
        },
      })

      jwt_validators.set_system_clock(function() return 0 end)

      local credentials, _, _, err = oidc:transform_credentials({ access_token = access_token })
      assert(credentials, err)

      jwt_validators.set_system_clock(function() return 1 end)

      credentials, _, err = oidc:transform_credentials({ access_token = access_token })

      assert.falsy(credentials, err)
    end)

    it('verifies alg', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'HS256' },
        payload = { },
      })

      local credentials, _, _, err = oidc:transform_credentials({ access_token = access_token })

      assert.match('invalid alg', err, nil, true)
      assert.falsy(credentials, err)
    end)

    it('validation fails when typ is invalid', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
        payload = {
          iss = service.oidc.issuer,
          aud = 'notused',
          azp = 'ce3b2e5e',
          nbf = 0,
          exp = ngx.now() + 10,
          typ = 'Not-Bearer'
        },
      })

      local credentials, _, _, err = oidc:transform_credentials({ access_token = access_token })
      assert.same("Claim 'typ' ('Not-Bearer') returned failure", err)
      assert.falsy(credentials, err)
    end)

    it('validation is successful when typ is included and is Bearer', function()
      local oidc = _M.new(service)
      local access_token = jwt:sign(rsa.private, {
        header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
        payload = {
          iss = service.oidc.issuer,
          aud = 'notused',
          azp = 'ce3b2e5e',
          nbf = 0,
          exp = ngx.now() + 10,
          typ = 'Bearer'
        },
      })

      local credentials, _, _, err = oidc:transform_credentials({ access_token = access_token })
      assert(credentials, err)
    end)
  end)

end)
