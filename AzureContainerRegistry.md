# Create container cluster (AKS)

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubesaks"
KUBE_NAME="dzkubes"
LOCATION="eastus"
REGISTRY_NAME=""
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

# Schedule container deployment

If the container registry is in the same resource group then no additional configration is needed

otherwise you can assign the kubernetes service prinicpal to the reader role of the container registry
```
az role assignment create --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.ContainerRegistry/registries/$REGISTRY_NAME --role Reader --assignee $SERVICE_PRINCIPAL_ID
```

trigger a deployment with a customer image to validate

```
kubectl run helloworld --image $REGISTRY_NAME.azurecr.io/aci-helloworld-ci:latest
```

# Deploy Secrets
https://kubernetes.io/docs/concepts/configuration/secret/

the secret for accessing your container registry

```
kubectl create secret docker-registry kuberegistry --docker-server 'myveryownregistry-on.azurecr.io' --docker-username 'username' --docker-password 'password' --docker-email 'example@example.com'

```

or

```
kubectl create secret docker-registry kuberegistry --docker-server $REGISTRY_URL --docker-username $REGISTRY_NAME --docker-password $REGISTRY_PASSWORD --docker-email 'example@example.com'
```
