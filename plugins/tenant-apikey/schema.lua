local typedefs = require "kong.db.schema.typedefs"


local PLUGIN_NAME = "tenant-apikey"

local function server_port(given_value, given_config)
  if given_value > 65534 then
    return false, "port value too high"
  end
end

local schema = {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
      type = "record",
      fields = {
        -- connection
        { timeout = { type = "number", default = 600000 }, },
        { keepalive = { type = "number", default = 60000 }, },
        { https = { type = "boolean", default = true }, },
        { https_verify = { type = "boolean", default = false }, },
        -- authorization
        --{ apikey = { type = "string", required = true, encrypted = true, referenceable = true }, }, -- encrypted = true is a Kong Enterprise Exclusive feature. It does nothing in Kong CE
        -- headers
        { header_upstream = { type = "string", required = true, default = "x-api-key" }, },
        { header_downstream = { type = "string", required = true, default = "tenant-id" }, },
        -- api
        { ariescloudurl = { type = "string", required = true }, },

        -- TODO: remove
        { request_header = typedefs.header_name {
          required = true,
          default = "Hello-World" } },

        { response_header = typedefs.header_name {
          required = true,
          default = "Bye-World" } },

        -- authorization      
        { keys = {
            type = "record",
            fields = {
              {
                governance = typedefs.host {
                  required = true
                },
              },
              {
                tenantadmin = typedefs.host {
                  required = true
                },
              },
            },
          },
        },        

        -- TODO: remove
        { request_header = typedefs.header_name {
          required = true,
          default = "Hello-World" } },

        { response_header = typedefs.header_name {
          required = true,
          default = "Bye-World" } },

      },
      entity_checks = {
        -- add some validation rules across fields
        -- the following is silly because it is always true, since they are both required
        { at_least_one_of = { "request_header", "response_header" }, },
        -- We specify that both header-names cannot be the same
        { distinct = { "request_header", "response_header" } },
      },
    },
    },
    -- { redis = { -- redis config
    --     type = "table",
    --     schema = {
    --         fields = {
    --             host = {type = "string", required = false},
    --             sentinel_master_name = {type = "string", required = false},
    --             sentinel_role = {type = "string", required = false, default = "master"},
    --             sentinel_addresses = {type = "array", required = false},
    --             port = {
    --                 type = "number",
    --                 func = server_port,
    --                 default = 6379,
    --                 required = true
    --             },
    --             timeout = {type = "number", required = true, default = 2000},
    --             password = {type = "string", required = false},
    --             database = {type = "number", required = true, default = 0},
    --             max_idle_timeout = {type = "number", required = true, default = 10000},
    --             pool_size = {type = "number", required = true, default = 1000}
    --         }
    --     }
    -- }}
  },
}

return schema
