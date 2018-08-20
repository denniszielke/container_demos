# Create container cluster (AKS)
https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubesaks"
KUBE_NAME="dzkubes"
LOCATION="westeurope"
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


2. Create the aks cluster
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3 --generate-ssh-keys --kubernetes-version 1.10.6
```

with existing keys and latest version
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --kubernetes-version 1.10.6 --enable-addons http_application_routing
```

with existing service principal

```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --kubernetes-version 1.10.6 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --enable-addons http_application_routing
```

with rbac (is now default)

```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --node-vm-size "Standard_B1ms" --enable-addons http_application_routing
```

without rbac ()
```
--disable-rbac
```

show deployment
```
az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME
```

deactivate routing addon
```
az aks disable-addons --addons http_application_routing --resource-group $KUBE_GROUP --name $KUBE_NAME
```

3. Export the kubectrl credentials files
```
az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

or If you are not using the Azure Cloud Shell and don’t have the Kubernetes client kubectl, run 
```
az aks install-cli
```

or download the file manually
```
scp azureuser@($KUBE_NAME)mgmt.westeurope.cloudapp.azure.com:.kube/config $HOME/.kube/config
```

4. Check that everything is running ok
```
kubectl version
kubectl config current-contex
```

Use flag to use context
```
kubectl --kube-context
```

5. Activate the kubernetes dashboard
```
az aks browse --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

6. Get all upgrade versions
```
az aks get-upgrades --resource-group=$KUBE_GROUP --name=$KUBE_NAME --output table
```

7. Perform upgrade
```
az aks upgrade --resource-group=$KUBE_GROUP --name=$KUBE_NAME --kubernetes-version 1.10.6
```

# Create and configure container registry

1. Create container registr
```
az acr create --resource-group "$KUBE_GROUP" --name "$REGISTRY_NAME" --sku Basic --admin-enabled true
```

2. Login to ACR
```
az acr login --name $REGISTRY_NAME
```

3. Read login servier
```
export REGISTRY_URL=$(az acr show -g $KUBE_GROUP -n $REGISTRY_NAME --query "loginServer")
export REGISTRY_URL=("${REGISTRY_URL[@]//\"/}")
```

# Deploy everything

kubectl create -f fulldeply.yml

Check status of the deployment
kubectl rollout history deployment/nginx-deployment

Rollback deployment
kubectl rollout undo deployment/nginx-deployment

# Delete everything
```
az group delete -n $KUBE_GROUP
```
