# Auth
https://github.com/mchmarny/dapr-demos/tree/master/hardened

```
TENANT_ID=
TENANT_NAME=*.onmicrosoft.com
SVC_APP_NAME=node-aad-svc
SVC_APP_ID=
SVC_APP_SECRET=
SVC_APP_SECRET_ENCODED=
SVC_APP_URI_ID=https://$TENANT_NAME/node-aad-svc

API_APP_NAME=name-aad-api
API_APP_ID=
API_APP_URI_ID=https://$TENANT_NAME/node-aad-api

WB_APP_NAME=Azure Blockchain Workbench Web Client
WB_APP_ID=
WB_APP_URI_ID=http://$TENANT_NAME.onmicrosoft.com/AzureBlockchainWorkbench/$/WebClient
WB_APP_URI_ID=$WB_APP_ID
Create azure ad app that will host our custom api

az ad app create --display-name node-aad-api --homepage http://localhost --identifier-uris https://$TENANT_NAME/node-aad-api
Create azure ad app that will be used to create an authentication token to call our custom api

az ad app create --display-name node-aad-svc --homepage http://localhost --identifier-uris https://$TENANT_NAME/node-aad-svc
Call azure AD to get bearer token for api

curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$SVC_APP_ID&resource=$API_APP_URI_ID&client_secret=$SVC_APP_SECRET_ENCODED&grant_type=client_credentials" "https://login.microsoftonline.com/$TENANT_ID/oauth2/token"
Call azure AD to get bearer token for workbench

curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$SVC_APP_ID&resource=$WB_APP_URI_ID&client_secret=$SVC_APP_SECRET_ENCODED&grant_type=client_credentials" "https://login.microsoftonline.com/$TENANT_ID/oauth2/token"
Set bearer token to env variable

TOKEN=
Try out bearer token

curl -isS -X GET -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"  'https://$$$-api.azurewebsites.net/api/v1/users'
Call our api with the bearer token

curl -isS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" http://127.0.0.1:3000/api
```