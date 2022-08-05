



```


SUBSCRIPTION_ID=$(az account show --query id -o tsv) 

az login --service-principal -u SPN_USER_NAME -p PASSWORD --tenant TENANT_ID_OR_NAME

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


```
az role definition create --role-definition '{
    "Name": "SecretProviderViewer",
    "Description": "Can read secretprovider",
    "Actions": [
        "Microsoft.ContainerService/managedClusters/*/read"
    ],
    "DataActions": [
    ],
    "NotDataActions": [
    ],
    "AssignableScopes": [
        "/subscriptions//resourcegroups/dzallincluded/providers/Microsoft.ContainerService/managedClusters/dzallincluded"
    ]
}'


az role assignment create --assignee $SERVICE_PRINCIPAL_ID --scope $AKS_ID --role "SecretProviderViewer"

```