

SUBSCRIPTION_ID=""

az login --service-principal -u SPN_USER_NAME -p PASSWORD --tenant TENANT_ID_OR_NAME


```
az role definition create --role-definition '{
    "Name": "Custom Container Service",
    "Description": "Cannot read Container service credentials",
    "Actions": [
        "Microsoft.ContainerService/managedClusters/read"
    ],
    "DataActions": [
    ],
    "NotDataActions": [
    ],
    "AssignableScopes": [
        "/subscriptions/xxx"
    ]
}'
```