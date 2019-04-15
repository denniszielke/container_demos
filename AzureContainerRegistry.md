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

# Run builds in ACR

https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-build-task

```
ACR_NAME=dzkubereg
RES_GROUP=kuberegistry
LOCATION=northeurope
USER=denniszielke

GIT_PAT=

az group create --resource-group $RES_GROUP --location $LOCATION

az acr create --resource-group $RES_GROUP --name $ACR_NAME --sku Standard --location $LOCATION

az acr build --registry $ACR_NAME --image helloacr:v1 .

az acr task list -o table

az acr task create --registry $ACR_NAME --name go-calc-backend-acr --image go-calc-backend:{{.Run.ID}} --context https://github.com/$USER/container_demos.git  --branch master --file apps/go-calc-backend/ACR.Dockerfile --git-access-token $GIT_PAT --no-cache true --set appfolder="apps/go-calc-backend/app" --arg appfolder="apps/go-calc-backend/app"

az acr task create --registry $ACR_NAME --name js-calc-backend-acr --image js-calc-backend:{{.Run.ID}} --context https://github.com/$USER/container_demos.git  --branch master --file apps/js-calc-backend/ACR.Dockerfile --git-access-token $GIT_PAT --no-cache true --set appfolder="apps/js-calc-backend/app" --arg appfolder="apps/js-calc-backend/app"

az acr task create --registry $ACR_NAME --name js-calc-frontend-acr --image js-calc-frontend:{{.Run.ID}} --context https://github.com/$USER/container_demos.git  --branch master --file apps/js-calc-frontend/ACR.Dockerfile --git-access-token $GIT_PAT --no-cache true --set appfolder="apps/js-calc-frontend/app" --arg appfolder="apps/js-calc-frontend/app"

az acr task run --registry $ACR_NAME --name go-calc-backend-acr
az acr task run --registry $ACR_NAME --name js-calc-backend-acr
az acr task run --registry $ACR_NAME --name js-calc-frontend-acr

```
