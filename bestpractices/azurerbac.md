

SUBSCRIPTION_ID=""

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