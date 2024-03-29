# aries-cloudapi-apim
This is a API Gateway for [Aries Cloud API](https://github.com/didx-xyz/aries-cloudapi-python). It acts as a wrapper around the Aries Cloud API and removes the burden of storing & managing api-keys for tenants from developers. It is intended to be used by consumers implementing the [Aries-CloudAPI-Dotnet](http://) .NET SDK. 

The solution utilizes [Kong](https://github.com/Kong/kong) for an API Gateway & [Konga](https://github.com/pantsel/konga) for an administration UI. 

Although not included in this project, some Kong plugins are utilized:
- [key-auth](https://github.com/Kong/kong/tree/master/kong/plugins/key-auth)
- [response-transformer](https://github.com/Kong/kong/tree/master/kong/plugins/response-transformer)

It also includes a custom Kong plugin called `tenant-keyapi` that handles the api keys for tenants.

![Overview](/docs/overview.png)

1) Consumers send HTTP Requests with the following HTTP headers:
- apikey: kong comsumer api key (key-auth plugin)
- tenant-id: `{ARIES_CLOUDAPI_TENANT_ID}` --or-- `{ARIES_CLOUDAPI_ROLE_NAME}`
    - `{ARIES_CLOUDAPI_TENANT_ID}` - tenant id of issuer/verifier/holder
    - `{ARIES_CLOUDAPI_ROLE_NAME}` - role name e.g governance or tenant-admin
2) Consumers are authenticated using the `apikey` header (key-auth plugin)
3) The `access_token` for `tenant-id` is retrieved from the aries-cloud-api (tenant-api plugin)
4) The `access_token` is cached in local session state (not persisted)
5) Sends original HTTP request
    - Removes `apikey` & `tenant-id` headers
    - Adds `x-api-key` header with access_token from 3)
6) Removes sensitive data from response e.g `access_token` (response-transformer plugin)

# Setup Kong + Konga using Docker compose
This repository was originally forked from [here](https://github.com/vousmeevoyez/kong-konga-example) so many thanks to the author!
Checkout the original article [here](https://dev.to/vousmeevoyez/setup-kong-konga-part-2-dan)

# Configuration
```bash
cp .env.sample .env
```
## Setup Kong LoopBack
```bash
curl --location --request POST 'http://localhost:8001/services/' --header 'Content-Type: application/json' --data-raw '{ "name": "admin-api", "host": "localhost", "port": 8001 }'
curl --location --request POST 'http://localhost:8001/services/admin-api/routes' --header 'Content-Type: application/json' --data-raw '{ "paths": ["/admin-api"] }'
```

## Enable Key Auth Plugin
```bash
curl -X POST http://localhost:8001/services/admin-api/plugins --data "name=key-auth" 
```

## Add Konga as Consumer
```bash
curl --location --request POST 'http://localhost:8001/consumers/' --form 'username=konga' --form 'custom_id=cebd360d-3de6-4f8f-81b2-31575fe9846a'
```

## Create API Key for Konga
```bash
curl --location --request POST 'http://localhost:8001/consumers/<id of preveious operation response>/key-auth'
# Example
curl --location --request POST 'http://localhost:8001/consumers/846f2bcc-bb99-40fd-a2fa-68d0e17917ba/key-auth'
```

## Manual Steps
- Create User. See [Image1](%2FScreen%20Shot%202020-12-03%20at%2007.28.18.png)
- Update connection. See [Image2](/setup.png)

## Create Aries Cloud API service
```bash
curl -i -X POST --url http://localhost:8001/services/ --data 'name=ariescloudapi-service' --data 'url={ARIES_CLOUD_API_URL}'  
curl -i -X POST --url http://localhost:8001/services/ariescloudapi-service/routes -d 'paths[]=/api'  
```
_{ARIES_CLOUD_API_URL} refers to the url of the Aries Cloud API e.g http://localhost:8100_

## Enable Key Auth Plugin
```bash
curl -X POST http://localhost:8001/services/ariescloudapi-service/plugins --data "name=key-auth" 
```

## Enable Response Transformer Plugin
```bash
curl -X POST http://localhost:8001/services/ariescloudapi-service/plugins --data "name=response-transformer" --data "config.remove.json=access_token"
```

## Enable Tenant Api Key Plugin
```bash
curl -i -X POST --url http://localhost:8001/services/ariescloudapi-service/plugins/ --data 'name=tenant-apikey' --data 'config.keys.governance=governance.adminApiKey' --data 'config.keys.tenantadmin=tenant-admin.adminApiKey' --data 'config.ariescloudurl={ARIES_CLOUD_API_URL}'
```
_{ARIES_CLOUD_API_URL} refers to the url of the Aries Cloud API e.g http://localhost:8100_

## Add Consumer
```bash
curl --location --request POST 'http://localhost:8001/consumers/' --form 'username={consumer_name}' --form 'custom_id=B51BB602-A28F-4177-B45D-8C3CA91F1F64'
```
_{consumer_name} refers to a consumer name e.g "ExampleConsumer"_
_note the {consumer_id} returned in the response_

## Create API Key for Consumer
```bash
curl --location --request POST 'http://localhost:8001/consumers/{consumer_id}/key-auth'
```
_{consumer_id} refers to the id of the consumer created above_

# Usage Examples
Consumers can now call the API endpoints using the `/api` route configured above. The `apikey` & `tenant-id` HTTP headers are required. 

For example:

```bash
curl -X 'GET' -H "apikey: {APIKEY}" -H "tenant-id: tenant-admin" http://localhost:8000/api/admin/tenants/
```

See [Aries Cloud API](https://github.com/didx-xyz/aries-cloudapi-python) for the API specification.

# Configure SSL certificates for Kong APIs
Follow the guide located [here](https://tech.aufomm.com/how-to-use-kong-acme-plugin/) to enable the Acme Plugin that allows you to use LetsEncrypt certificates to protect API endpoints. This is required if you want to use OAuth2 etc.

## .env file changes
The following values must be added/changed in the .env file to make the plugin work and receive a certificate from LetsEncrypt:

**Change:**

`KONG_PROXY_PORT=80`

`KONG_PROXY_SSL_PORT=443`

**Add:**

`# KONG ACME LETSENCRYPT SETTING`

`KONG_LUA_SSL_TRUSTED_CERTIFICATE=system`

## docker-compose.yml changes
And the following changes are required in `docker-compose.yml` under the `kong` service:

**Add:**

`KONG_LUA_SSL_TRUSTED_CERTIFICATE: system`. 

