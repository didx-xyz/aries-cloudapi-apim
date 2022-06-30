local plugin = {
  PRIORITY = 1350, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

local constants = require "kong.constants"
local meta      = require "kong.meta"
local http      = require "resty.http"
local kong_meta = require "kong.meta"

local kong          = kong
local fmt           = string.format
local var           = ngx.var
local pairs         = pairs
local server_header = meta._SERVER_TOKENS
local conf_cache    = setmetatable({}, { __mode = "k" })
local req_set_header = ngx.req.set_header

local cjson = require "cjson"

-- get tenant_id from header
local function getTenantIdFromRequestHeader(conf)
  local request_headers = kong.request.get_headers()
  local tenant_id = request_headers[conf.header_downstream]
  if not tenant_id then
    local err = "Missing '" .. conf.header_downstream .. "' http request header"
    kong.log.err(err)
    return kong.response.exit(401, { message = err })
  end
  return tenant_id;
end

-- calls the aries cloud endpoint to get the access_token for a tenant
local function loadAccessTokenFromAriesCloud(conf, tenant_id)

  -- get the aries cloud url
  local uri = conf.ariescloudurl
  local path = '/admin/tenants/' .. tenant_id .. '/access-token';

  -- add x-api-key header
  local request_headers = {
    [conf.header_upstream] = conf.keys.tenantadmin
  }
  -- send request
  kong.log.debug("***  Sending request: " .. uri .. path)

  local client = http.new()
  client:set_timeout(conf.timeout)
  local res, err = client:request_uri(uri, {
    method = 'GET',
    path = path,
    body = nil,
    query = nil,
    headers = request_headers,
    ssl_verify = conf.https_verify,
    keepalive_timeout = conf.keepalive,
  })

  if not res then
    kong.log.err(err)
    return kong.response.exit(500, { message = "An unexpected error occurred" })
  end

  -- response
  kong.log.debug("***  Received response...")

  -- parse json from body
  kong.log.debug("***  Parsing response body...")
  kong.log.inspect(res.body)
  local table = cjson.decode(res.body)
  local access_token = table["access_token"]

  return access_token
end

-- gets the access_token for a tenant from AriesHyperCloudAPI
local function getAccessTokenForTenant(conf, tenant_id)

  -- check for system roles
  if (tenant_id == 'governance') then
    return conf.keys.governance
  end
  if (tenant_id == 'tenant-admin') then
    return conf.keys.tenantadmin
  end

  -- return for individual tenant
  --local credential_cache_key = kong.db.arieskeyauth_credentials:cache_key(tenant_id)
  local credential_cache_key = "arieskeyauth_credentials:" .. tenant_id
   
  kong.log.err("DB credential_cache_key: " .. credential_cache_key)
  -- We are using cache.get to first check if the apikey has been already
  -- stored into the in-memory cache. If it's not, then we lookup the datastore
  -- and return the credential object. Internally cache.get will save the value
  -- in-memory, and then return the credential.
  local credential, err = kong.cache:get(credential_cache_key, nil, loadAccessTokenFromAriesCloud, conf, tenant_id)
 
  if credential then
    kong.log.err("FOUND IN CACHE:" .. credential)
    return credential
  end

  if err then
    kong.log.err(err)
    return kong.response.exit(500, {
      message = "Unexpected error"
    })
  end

  if not credential then
    -- no credentials in cache nor datastore
    return kong.response.exit(401, {
      message = "Invalid authentication credentials"
    })
  end
end

local function insertCredential()
  kong.log.debug("Insert_Credential...")

  local entity, err = kong.db.arieskeyauth_credentials:insert({
    consumer = { id = "c77c50d2-5947-4904-9f37-fa36182a71a9" },
    key = "secret",
  })

  if not entity then
    kong.log.err("Error when inserting keyauth credential: " .. err)
    return nil
  end

  return entity
end

local function loadCredential(key)
  kong.log.debug("Load_Credential...")

  local cred, err = kong.db.arieskeyauth_credentials:select_by_key(key)
  if not cred then
    kong.log.debug("NULL...creating")
    return insertCredential()
    --return nil, err
  end

  kong.log.debug("NOT NULL...")

  return cred, nil, cred.ttl
end

-- Executed upon every Nginx worker process’s startup
function plugin:init_worker()
end

-- Executed for every request from a client and before it is being proxied to the upstream service.
function plugin:access(conf)
  local tenant_id = getTenantIdFromRequestHeader(conf)
  local access_token = getAccessTokenForTenant(conf, tenant_id)
 
  if not access_token then
    --return kong.response.error(403, 'Could not find access_token')
    return kong.response.exit(401, { message = 'Could not find access_token' })
  end

  -- kong.log.err("GOT ACCESS TOKEN: " .. access_token .. " header_upstream: " .. conf.header_upstream .. " header_downstream: " .. conf.header_downstream)
  
  kong.service.request.add_header(conf.header_upstream, access_token) 
  kong.service.request.set_header(conf.header_upstream, access_token) 
  req_set_header(conf.header_upstream, access_token) 
  
  --kong.log.err("SET HTTP HEADER: " .. conf.header_upstream .. ": " .. access_token)
 
  --kong.log.inspect(kong.service.request)

  -- your custom code here
  -- kong.log.inspect(conf) -- check the logs for a pretty-printed config!
  --kong.service.request.set_header(conf.request_header, "this is on a request")
end

-- Executed when all response headers bytes have been received from the upstream service.
function plugin:header_filter(conf) 

  -- your custom code here, for example;
  --kong.response.set_header(conf.response_header, "this is on the response")

end

-- Executed for each chunk of the response body received from the upstream service. Since the response is streamed back to the client, it can exceed the buffer size and be streamed chunk by chunk. This function can be called multiple times if the response is large.
--function plugin:body_filter(conf)

--todo
--remove api-key & tenant-id headers

-- your custom code here, for example;
--kong.response.set_header(conf.response_header, "this is on the response")

--end --]]

-- local function load_entity(conf)
--   local entity, err = kong.db.api_version:select({
--     id = "c77c50d2-5947-4904-9f37-fa36182a71a9"
--   })

--   if err then
--     kong.log.err("Error when inserting keyauth credential: " .. err)
--     --return nil
--   end

--   if not entity then
--     kong.log.err("Could not find credential.")
--     --return nil
--   end
-- end

--[[ runs in the 'body_filter_by_lua_block'
function plugin:body_filter(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'body_filter' handler")

end --]]


--[[ runs in the 'log_by_lua_block'
function plugin:log(conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'log' handler")

end --]]

return plugin
