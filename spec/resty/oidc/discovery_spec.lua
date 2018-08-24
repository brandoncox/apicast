local test_backend_client = require 'resty.http_ng.backend.test'
local _M = require('resty.oidc.discovery')
local cjson = require('cjson')

describe('OIDC Discovery', function()
    local test_backend
    before_each(function() test_backend = test_backend_client.new() end)

    local discovery
    before_each(function() discovery = _M.new(test_backend) end)

    describe('.new', function()
        it('has .http_client', function()
            assert(_M.new().http_client,'has .http_client')
        end)
    end)

    describe(':openid_configuration(endpoint)', function()
        it('loads configuration from the discovery endpoint', function()
            test_backend
                .expect{ url = "https://idp.example.com/auth/realms/foo/.well-known/openid-configuration" }
                .respond_with{ status = 200, headers = { content_type = 'application/json' }, body = [[
                    {
                      "issuer": "https://idp.example.com/auth/realms/foo",
                      "jwks_uri": "https://idp.example.com/auth/realms/foo/jwks",
                      "id_token_signing_alg_values_supported": [ "RS256" ]
                    }
                  ]] }

            local config = assert(discovery:openid_configuration('https://idp.example.com/auth/realms/foo'))

            assert.same({
                id_token_signing_alg_values_supported = { 'RS256' },
                issuer = 'https://idp.example.com/auth/realms/foo',
                jwks_uri = 'https://idp.example.com/auth/realms/foo/jwks',
            }, config)
        end)
    end)

    describe(':jwks(config)', function()

        it('loads and decodes keys from jwks_uri endpoint', function()
            local config = { jwks_uri = 'https://idp.example.com/auth/realms/foo/jwks' }
            test_backend
                .expect{ url = config.jwks_uri }
                .respond_with{
                    status = 200,
                    headers = { content_type = 'application/json' },
                    body =  [[ { "keys": [{
                      "kid": "3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y",
                      "kty": "RSA",
                      "n": "iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw",
                      "e": "AQAB"
                    }] } ]]
                }

            local keys = assert(discovery:jwks(config))

            assert.same({ ['3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y'] = {
                e = 'AQAB',
                kid = '3g-I9PWt6NrznPLcbE4zZrakXar27FDKEpqRPlD2i2Y',
                kty = 'RSA',
                n = 'iqXwBiZgN2q1dCKU1P_vzyiGacdQhfqgxQST7GFlWU_PUljV9uHrLOadWadpxRAuskNpXWsrKoU_hDxtSpUIRJj6hL5YTlrvv-IbFwPNtD8LnOfKL043_ZdSOe3aT4R4NrBxUomndILUESlhqddylVMCGXQ81OB73muc9ovR68Ajzn8KzpU_qegh8iHwk-SQvJxIIvgNJCJTC6BWnwS9Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG-fqUAPHy5IYQaD8k8QX0obxJ0fld61fH-Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf-KrSagD5GUw',
                pem = [[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiqXwBiZgN2q1dCKU1P/v
zyiGacdQhfqgxQST7GFlWU/PUljV9uHrLOadWadpxRAuskNpXWsrKoU/hDxtSpUI
RJj6hL5YTlrvv+IbFwPNtD8LnOfKL043/ZdSOe3aT4R4NrBxUomndILUESlhqddy
lVMCGXQ81OB73muc9ovR68Ajzn8KzpU/qegh8iHwk+SQvJxIIvgNJCJTC6BWnwS9
Bw2ns0fQOZZRjWFRVh8BjkVdqa4vCAb6zw8hpR1y9uSNG+fqUAPHy5IYQaD8k8QX
0obxJ0fld61fH+Wr3ENpn9YZWYBcKvnwLm2bvxqmNVBzW4rhGEZb9mf+KrSagD5G
UwIDAQAB
-----END PUBLIC KEY-----
]],
            } }, keys)
        end)

        it('can process ForgeRock response', function()
            local config = { jwks_uri = 'https://idp.example.com/auth/realms/foo/jwks' }
            test_backend
                .expect{ url = config.jwks_uri }
                .respond_with{
                    status = 200,
                    headers = { content_type = 'application/json' },
                    body = fixture('oidc', 'jwk', 'forgerock.json')
                }

            local keys = assert(discovery:jwks(config))

            assert.same(cjson.decode(fixture('oidc', 'jwk', 'forgerock.apicast.json')),
                    keys)
        end)

        it('ignores empty jwks_uri', function()
            assert.returns_error('no jwks_uri', discovery:jwks{})
            assert.returns_error('no jwks_uri', discovery:jwks{ jwks_uri = ngx.null })
        end)

        it('ignores empty config', function()
            assert.returns_error('no config', discovery:jwks())
        end)
    end)
end)
