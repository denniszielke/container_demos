# Launch the multicalculator from ACI

0. Variables
```
SUBSCRIPTION_ID=""
ACI_GROUP="calculator"
ACI_GO_BACKEND="dzgobackend"
ACI_JS_BACKEND="dzjsbackend"
ACI_JS_FRONTEND="dzjsfrontend"
LOCATION="EASTUS"
REGISTRY_NAME=""
APPINSIGHTS_KEY=""

```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create backend
```
az container create -g $ACI_GROUP --name myapp --image alpine:latest --command-line "cat /mnt/azfile/myfile" --azure-file-volume-share-name myshare --azure-file-volume-account-name mystorageaccount --azure-file-volume-account-key mystoragekey --azure-file-volume-mount-path /mnt/azfile

```